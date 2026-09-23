"""
The 64 districts of Bangladesh, matching lib/core/districts.dart.

Reports are grouped by district, so the server only accepts official
names. This fixes two problems at once: misspellings that would split one
district's reports across several names, and invented district names
that would let anyone create outbreak buckets at will.

It also replaces the old str.title() normalisation, which turned
"Cox's Bazar" into "Cox'S Bazar".

Change this file and the Dart one together.
"""

import re

DISTRICTS = [
    "Dhaka",
    "Faridpur",
    "Gazipur",
    "Gopalganj",
    "Kishoreganj",
    "Madaripur",
    "Manikganj",
    "Munshiganj",
    "Narayanganj",
    "Narsingdi",
    "Rajbari",
    "Shariatpur",
    "Tangail",
    "Bandarban",
    "Brahmanbaria",
    "Chandpur",
    "Chattogram",
    "Cox's Bazar",
    "Cumilla",
    "Feni",
    "Khagrachhari",
    "Lakshmipur",
    "Noakhali",
    "Rangamati",
    "Bogura",
    "Chapai Nawabganj",
    "Joypurhat",
    "Naogaon",
    "Natore",
    "Pabna",
    "Rajshahi",
    "Sirajganj",
    "Bagerhat",
    "Chuadanga",
    "Jashore",
    "Jhenaidah",
    "Khulna",
    "Kushtia",
    "Magura",
    "Meherpur",
    "Narail",
    "Satkhira",
    "Barguna",
    "Barishal",
    "Bhola",
    "Jhalokati",
    "Patuakhali",
    "Pirojpur",
    "Habiganj",
    "Moulvibazar",
    "Sunamganj",
    "Sylhet",
    "Dinajpur",
    "Gaibandha",
    "Kurigram",
    "Lalmonirhat",
    "Nilphamari",
    "Panchagarh",
    "Rangpur",
    "Thakurgaon",
    "Jamalpur",
    "Mymensingh",
    "Netrokona",
    "Sherpur",
]

# Old spellings still seen on forms and signs, and "Savar", an upazila
# early versions of the app used as a default district.
ALIASES = {
    "bogra": "Bogura",
    "chittagong": "Chattogram",
    "comilla": "Cumilla",
    "barisal": "Barishal",
    "jessore": "Jashore",
    "nawabganj": "Chapai Nawabganj",
    "laxmipur": "Lakshmipur",
    "maulvibazar": "Moulvibazar",
    "netrakona": "Netrokona",
    "jhalakathi": "Jhalokati",
    "jhalokathi": "Jhalokati",
    "khagrachari": "Khagrachhari",
    "narshingdi": "Narsingdi",
    "hobiganj": "Habiganj",
    "jhenaidaha": "Jhenaidah",
    "coxbazar": "Cox's Bazar",
    "savar": "Dhaka",
}


def _key(s: str) -> str:
    return re.sub(r"[^a-z]", "", s.lower())


_BY_KEY = {_key(d): d for d in DISTRICTS}
_BY_KEY.update(ALIASES)


def normalize_district(value: str):
    """The official name for value, or None if it is not a district."""
    return _BY_KEY.get(_key(value or ""))
