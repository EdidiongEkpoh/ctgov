import pandas as pd
df = pd.read_excel('scripts/data/ZIP-COUNTY_062026.xlsx', dtype={"ZIP": str, "COUNTY": str})
out = (
    df[["zip", "geoid", "res_ratio"]]
    .rename(columns={"geoid": "county_fips"})
    .assign(
        zip=lambda d: d["zip"].astype("string").str.strip().str.zfill(5),
        county_fips=lambda d: d["county_fips"].astype("string").str.strip().str.zfill(5),
        res_ratio=lambda d: d["res_ratio"].astype(float)
    )
)

assert out["zip"].str.len().eq(5).all(), "some ZIPs aren't 5 digits"
assert out["county_fips"].str.len().eq(5).all(), "geoid isn't a 5-digit county code - wrong file?"
print(len(out), "rows,", out["zip"].nunique(), "ZIPs,", out["county_fips"].nunique(), "counties")
out.to_csv("dbt/seeds/zip_county_crosswalk.csv", index=False)