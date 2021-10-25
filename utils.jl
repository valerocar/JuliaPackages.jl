using PlotlyJS
using RemoteFiles

# For createing plot elements and arrays
PlotElement = GenericTrace{Dict{Symbol,Any}}
PlotArray(; n = 0) = Vector{PlotElement}(undef, n)

colors = 
[
    "#1f77b4",  # muted blue
    "#ff7f0e",  # safety orange
    "#2ca02c",  # cooked asparagus green
    "#d62728",  # brick red
    "#9467bd",  # muted purple
    "#8c564b",  # chestnut brown
    "#e377c2",  # raspberry yogurt pink
    "#7f7f7f",  # middle gray
    "#bcbd22",  # curry yellow-green
    "#17becf"   # blue-teal
]


function load_dataframe()
    file_name = "package_requests_by_date.csv.gz"
    stats_base = "https://julialang-logs.s3.amazonaws.com/public_outputs/current"
    r = RemoteFile(stats_base * "/" * file_name, dir = ".")
    download(r)
    DataFrame(load(File(format"CSV", "./package_requests_by_date.csv.gz")))
end

function lookup(name)
    # Look up Registry.toml files in depots
    tomlfiles = String[]
    for d in DEPOT_PATH
        regs = joinpath(d, "registries")
        if isdir(regs)
            for r in readdir(regs)
                toml = joinpath(regs, r, "Registry.toml")
                if isfile(toml)
                    push!(tomlfiles, toml)
                end
            end
        end
    end

    # Look up uuids in toml files
    uuids = Base.UUID[]
    for f in tomlfiles
        toml = TOML.parsefile(f)
        if haskey(toml, "packages")
            for (k, v) in toml["packages"]
                if v["name"] == name
                    push!(uuids, Base.UUID(k))
                end
            end
        end
    end
    return uuids
end

movingaverage(g, n) = [i < n ? mean(g[begin:i]) : mean(g[i-n+1:i]) for i = 1:length(g)]

layout = Layout(;
    title = "",
    width = 600,
    height = 400,
    xaxis = attr(title = "Date"),
    yaxis = attr(title = "Requests"),
)

c_layout = Layout(;
    title = "",
    width = 500,
    height = 400,
    xaxis = attr(title = "Date"),
    yaxis = attr(title = "Cumulative Requests"),
)



function package_dataframe(package_name)
    result = lookup(package_name)
    if length(result) > 0
        uuid = string(result[1])
        mask = ((df."package_uuid" .== uuid) .& (df."status" .== 200))
        return df[mask, :]
    end
    nothing
end


function linear_regression(x, y)
    xd = Dates.value.(x - x[begin])
    mx = mean(xd) # Mean for days
    my = mean(y) # Mean for requests

    β = sum((xd .- mx) .* (y .- my)) / sum((xd .- mx) .* (xd .- mx))
    α = my - β * mx
    return β .* xd .+ α, β, α
end


function scatter_by_client(
    pdf::DataFrame,
    client_type::String,
    data_x,
    data_y,
    check_vals;
    start_date = nothing,
    end_date = nothing,
    name = "",
    color="green"
)
    mask = (pdf."client_type" .== client_type)
    if start_date !== nothing
        sd = Date(start_date[1:10])
        cond = (pdf."date" .>= sd)
        mask = (mask .& cond)
    end
    if end_date !== nothing
        ed = Date(end_date[1:10])
        cond = (pdf."date" .<= ed)
        mask = (mask .& cond)
    end
    cpdf = pdf[mask, :]
    x = cpdf[:, data_x]
    y = cpdf[:, data_y]
    days = Dates.value(x[end] - x[begin])
    total_requests = sum(y)
    # Moving averages
    my = movingaverage(y, 7)
    ly, β, α = linear_regression(x, y)

    precision = 4
    α = round(α, digits = precision)
    β = round(β, digits = precision)
    μ = round(sum(y) / days, digits = precision)

    info = Dict("total" => total_requests, "interval" => days, "α" => α, "β" => β)

    extra_plots = Dict(
        "MA" => scatter(x = x, y = my, mode = "lines", name = "μ", showlegend = false, line_color=color, line_width=1.5),
        "RL" => scatter(x = x, y = ly, mode = "lines", name = "L", showlegend = false, line_color=color, line_width=2),
    )
    plots = [scatter(x = x, y = y, mode = "lines+markers", name = name, line_color=color,line_width=2)]
    append!(plots, [extra_plots[k] for k in check_vals])
    c_plots = [scatter(x = x, y = cumsum(y), mode = "lines", name = name, line_color=color)]
    return plots, c_plots, info
end

function plot_default(;cumulative = false)
    fig = scatter(x = [0], y = [0], mode = "lines")
    lo = layout
    if cumulative
        lo = c_layout
    end
    plot(fig, lo)
end


function plot_graphs(options, check_vals, client_type; start_date = nothing, end_date = nothing)
    if (options !== nothing)
        if length(options) == 0
            return plot_default()
        end
        plot_data = PlotArray()
        c_plot_data = PlotArray()
        stats_info = []
        
        for (i,op) in enumerate(options)
            plots, cu, info = scatter_by_client(
                package_dataframe(op),
                client_type,
                "date",
                "request_count",
                check_vals,
                start_date = start_date,
                end_date = end_date,
                name = op,
                color=colors[i]
            )
            append!(plot_data, plots)
            append!(c_plot_data, cu)
            append!(stats_info, [info])
        end
        return plot(plot_data, layout), plot(c_plot_data, c_layout), stats_info
    end
    return plot_default(), plot_default(cumulative=true), []
end
