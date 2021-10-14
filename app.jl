using Pkg
Pkg.activate(".")
using RemoteFiles
using Dash, PlotlyJS
using CSVFiles
using DataFrames

stats_base = "https://julialang-logs.s3.amazonaws.com/public_outputs/current/"
ext = ".csv.gz"

@RemoteFileSet JULIAPACKAGES "Julia Packages" begin
    client_types = @RemoteFile stats_base*"client_types"*ext
    client_types_by_region = @RemoteFile stats_base*"client_types_by_region"*ext
    client_types_by_date = @RemoteFile stats_base*"client_types_by_date"*ext
    client_types_by_region_by_date = @RemoteFile stats_base*"client_types_by_region_by_date"*ext
    julia_systems = @RemoteFile stats_base*"julia_systems"*ext
    julia_systems_by_region = @RemoteFile stats_base*"julia_systems_by_region"*ext
    julia_systems_by_date = @RemoteFile stats_base*"julia_systems_by_date"*ext
    julia_systems_by_region_by_date = @RemoteFile stats_base*"julia_systems_by_region_by_date"*ext
    julia_versions = @RemoteFile stats_base*"julia_versions"*ext
    julia_versions_by_region = @RemoteFile stats_base*"julia_versions_by_region"*ext
    julia_versions_by_date = @RemoteFile stats_base*"julia_versions_by_date"*ext
    julia_versions_by_region_by_date = @RemoteFile stats_base*"julia_versions_by_region_by_date"*ext
    resource_types = @RemoteFile stats_base*"resource_types"*ext
    resource_types_by_region = @RemoteFile stats_base*"resource_types_by_region"*ext
    resource_types_by_date = @RemoteFile stats_base*"resource_types_by_date"*ext
    resource_types_by_region_by_date = @RemoteFile stats_base*"resource_types_by_region_by_date"*ext
    package_requests = @RemoteFile stats_base*"package_requests"*ext
    package_requests_by_region = @RemoteFile stats_base*"package_requests_by_region"*ext
    package_requests_by_date = @RemoteFile stats_base*"package_requests_by_date"*ext
    package_requests_by_region_by_date = @RemoteFile stats_base*"package_requests_by_region_by_date"*ext
end

rollups = [
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

data_dir = "../data/"
df = DataFrame(load(File(format"CSV", data_dir*"client_types.csv.gz")))
#for r in rollups
#    println(r*" = @RemoteFile stats_base*\"$r\"*ext")
#end
