"""Creates Examly's Google Play products to match docs/MONETIZATION.md.

- Subscriptions premium_annual (base plan "annual" with offers trial / welcome / winback)
  and premium_monthly (base plan "monthly"); USD base price converted to every region by Play,
  Turkey set explicitly.
- Consumables ai_credits_small / medium / large.
- Store contact details.

Safe to re-run: existing products are left as they are.
Usage: python store/play_products.py ~/.examly/play-service-account.json [subscriptions|consumables]
"""
import sys

import requests
from google.auth.transport.requests import Request
from google.oauth2 import service_account

PKG = "com.techtactoe.examly"
API = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PKG}"
REGIONS_VERSION = {}  # filled from convertRegionPrices so prices match the current region list

creds = service_account.Credentials.from_service_account_file(
    sys.argv[1], scopes=["https://www.googleapis.com/auth/androidpublisher"])
creds.refresh(Request())
session = requests.Session()
session.headers["Authorization"] = f"Bearer {creds.token}"


def call(method, path, **kwargs):
    response = session.request(method, API + path, **kwargs)
    try:
        body = response.json() if response.content else {}
    except ValueError:
        body = {"error": {"message": response.text[:300]}}
    return response.status_code, body


def money(currency, amount):
    units = int(amount)
    return {"currencyCode": currency, "units": str(units), "nanos": round((amount - units) * 1e9)}


def converted(usd):
    status, body = call("POST", "/pricing:convertRegionPrices", json={"price": money("USD", usd)})
    assert status == 200, body
    REGIONS_VERSION["regionsVersion.version"] = body["regionVersion"]["version"]
    return body


def regional_configs(usd, tr_price):
    body = converted(usd)
    configs = []
    for region, value in body["convertedRegionPrices"].items():
        price = value["price"]
        if region == "TR":
            price = money("TRY", tr_price)
        configs.append({"regionCode": region, "price": price, "newSubscriberAvailability": True})
    return configs, body["convertedOtherRegionsPrice"]


def subscription(product_id, title, description, base_plan_id, period, usd, tr_price):
    configs, other = regional_configs(usd, tr_price)
    body = {
        "packageName": PKG,
        "productId": product_id,
        "listings": [{"languageCode": "en-US", "title": title, "description": description}],
        "basePlans": [{
            "basePlanId": base_plan_id,
            "autoRenewingBasePlanType": {
                "billingPeriodDuration": period,
                "gracePeriodDuration": "P7D",
                "resubscribeState": "RESUBSCRIBE_STATE_ACTIVE",
                "legacyCompatible": True,
            },
            "regionalConfigs": [{"regionCode": c["regionCode"], "price": c["price"],
                                 "newSubscriberAvailability": True} for c in configs],
            "otherRegionsConfig": {"usdPrice": other["usdPrice"], "eurPrice": other["eurPrice"],
                                   "newSubscriberAvailability": True},
        }],
    }
    status, result = call("POST", "/subscriptions", params={"productId": product_id, **REGIONS_VERSION}, json=body)
    print(product_id, status, result.get("error", {}).get("message", "created"))
    status, result = call("POST", f"/subscriptions/{product_id}/basePlans/{base_plan_id}:activate", json={})
    print(f"  activate {base_plan_id}", status, result.get("error", {}).get("message", "ok"))
    return [c["regionCode"] for c in configs]


def offer(product_id, base_plan_id, offer_id, phase, regions, new_customers_only=False):
    body = {
        "packageName": PKG,
        "productId": product_id,
        "basePlanId": base_plan_id,
        "offerId": offer_id,
        "offerTags": [{"tag": offer_id}],
        "phases": [phase(regions)],
        "regionalConfigs": [{"regionCode": r, "newSubscriberAvailability": True} for r in regions],
        "otherRegionsConfig": {"otherRegionsNewSubscriberAvailability": True},
    }
    if new_customers_only:
        # Play decides eligibility: only people who never had this subscription.
        body["targeting"] = {"acquisitionRule": {"scope": {"thisSubscription": {}}}}
    # Without targeting the offer is developer-determined: the app only shows it when the
    # server issued a matching offer.
    path = f"/subscriptions/{product_id}/basePlans/{base_plan_id}/offers"
    status, result = call("POST", path, params={"offerId": offer_id, **REGIONS_VERSION}, json=body)
    print(f"  offer {offer_id}", status, result.get("error", {}).get("message", "created"))
    status, result = call("POST", f"{path}/{offer_id}:activate", json={})
    print(f"  activate {offer_id}", status, result.get("error", {}).get("message", "ok"))


def free_week(regions):
    return {"recurrenceCount": 1, "duration": "P7D",
            "regionalConfigs": [{"regionCode": r, "free": {}} for r in regions],
            "otherRegionsConfig": {"free": {}}}


def discount_year(share):
    def phase(regions):
        return {"recurrenceCount": 1, "duration": "P1Y",
                "regionalConfigs": [{"regionCode": r, "relativeDiscount": share} for r in regions],
                "otherRegionsConfig": {"relativeDiscount": share}}
    return phase


def consumable(sku, title, description, usd, tr_price):
    body = converted(usd)
    configs = []
    for region, value in body["convertedRegionPrices"].items():
        price = money("TRY", tr_price) if region == "TR" else value["price"]
        configs.append({"regionCode": region, "price": price, "availability": "AVAILABLE"})
    other = body["convertedOtherRegionsPrice"]
    product = {
        "packageName": PKG,
        "productId": sku,
        "listings": [{"languageCode": "en-US", "title": title, "description": description}],
        "purchaseOptions": [{
            "purchaseOptionId": "buy",
            "buyOption": {"legacyCompatible": True, "multiQuantityEnabled": False},
            "regionalPricingAndAvailabilityConfigs": configs,
            "newRegionsConfig": {"usdPrice": other["usdPrice"], "eurPrice": other["eurPrice"],
                                 "availability": "AVAILABLE"},
        }],
    }
    status, result = call("PATCH", f"/oneTimeProducts/{sku}",
                          params={"allowMissing": "true", "updateMask": "listings,purchaseOptions",
                                  **REGIONS_VERSION}, json=product)
    print(sku, status, result.get("error", {}).get("message", "saved"))
    status, result = call("POST", f"/oneTimeProducts/{sku}/purchaseOptions:batchUpdateStates", json={
        "requests": [{"activatePurchaseOptionRequest": {
            "packageName": PKG, "productId": sku, "purchaseOptionId": "buy"}}]})
    print(f"  activate {sku}", status, result.get("error", {}).get("message", "ok"))


def contact_details():
    status, edit = call("POST", "/edits", json={})
    assert status == 200, edit
    status, result = call("PATCH", f"/edits/{edit['id']}/details", json={
        "contactEmail": "techtactoeappstudio@gmail.com",
        "contactWebsite": "https://examly-study.web.app",
        "defaultLanguage": "en-US",
    })
    print("details", status, result.get("error", {}).get("message", "ok"))
    status, result = call("POST", f"/edits/{edit['id']}:commit")
    print("commit", status, result.get("error", {}).get("message", "ok"))



ONLY = sys.argv[2] if len(sys.argv) > 2 else None

if ONLY in (None, "subscriptions"):
    regions = subscription("premium_annual", "Examly Premium (Annual)",
                           "Unlimited AI tutor, mock exams, voice tutor and study tools.",
                           "annual", "P1Y", 49.99, 899.99)
    offer("premium_annual", "annual", "trial", free_week, regions, new_customers_only=True)
    offer("premium_annual", "annual", "welcome", discount_year(0.4), regions)
    offer("premium_annual", "annual", "winback", discount_year(0.5), regions)
    subscription("premium_monthly", "Examly Premium (Monthly)",
                 "Unlimited AI tutor, mock exams, voice tutor and study tools.",
                 "monthly", "P1M", 7.99, 149.99)


if ONLY in (None, "consumables"):
    consumable("ai_credits_small", "50 AI credits", "Credits for AI image and video lessons", 2.99, 49.99)
    consumable("ai_credits_medium", "150 AI credits", "Credits for AI image and video lessons", 6.99, 129.99)
    consumable("ai_credits_large", "500 AI credits", "Credits for AI image and video lessons", 19.99, 349.99)
