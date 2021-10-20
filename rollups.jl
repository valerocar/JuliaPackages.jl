using RemoteFiles

stats_base = "https://julialang-logs.s3.amazonaws.com/public_outputs/current/"
ext = ".csv.gz"

all_rollups = [
"client_types",
"client_types_by_region",
"client_types_by_date",
"client_types_by_region_by_date",
"julia_systems",
"julia_systems_by_region",
"julia_systems_by_date",
"julia_systems_by_region_by_date",
"julia_versions",
"julia_versions_by_region",
"julia_versions_by_date",
"julia_versions_by_region_by_date",
"resource_types",
"resource_types_by_region",
"resource_types_by_date",
"resource_types_by_region_by_date",
"package_requests",
"package_requests_by_region",
"package_requests_by_date",
"package_requests_by_region_by_date"
]
