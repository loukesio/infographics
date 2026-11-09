"""Anonymous DuckDB access to Overture Maps (OSM-derived) on S3, clipped to the Thessaly bbox."""
import os, duckdb
RELEASE = "2026-10-21.0"
BB = "bbox.xmin < 24.4 AND bbox.xmax > 20.9 AND bbox.ymin < 40.3 AND bbox.ymax > 38.8"
def con():
    for k in ("AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY"): os.environ.pop(k, None)
    c = duckdb.connect()
    c.sql("INSTALL httpfs; LOAD httpfs; INSTALL spatial; LOAD spatial; SET s3_region='us-west-2'; SET s3_access_key_id=''; SET s3_secret_access_key='';")
    return c
def path(theme, typ): return f"s3://overturemaps-us-west-2/release/{RELEASE}/theme={theme}/type={typ}/*"
