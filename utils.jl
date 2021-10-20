using PlotlyJS
using RemoteFiles

function load_dataframe()    
    file_name = "package_requests_by_date.csv.gz"
    stats_base = "https://julialang-logs.s3.amazonaws.com/public_outputs/current"
    r = RemoteFile(stats_base*"/"*file_name, dir=".")
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

movingaverage(g, n) = [i < n ? mean(g[begin:i]) : mean(g[i-n+1:i]) for i in 1:length(g)]

layout = Layout(;title="",width=600, height=400, xaxis=attr(title="Date"), yaxis=attr(title="Requests Count"))

function package_dataframe(package_name)
    result = lookup(package_name)
    if length(result) > 0
        uuid = string(result[1])
        mask = ((df."package_uuid" .== uuid) .& (df."status" .== 200))
        return df[mask,:]
    end
    nothing
end

function linear_regression(df::DataFrame)
    days = df."date"-df."date"[begin]
    daysi = [Dates.value(d) for d in days] # Days as integers
    reqs = df."request_count"

    md = mean(daysi) # Mean for days
    mr = mean(reqs) # Mean for requests

    β = sum((daysi .-md).*(reqs .-mr))/sum((daysi .-md).*(daysi .-md))
    α = mr -β*md
    return β.*daysi.+α, β, α
end

function scatter_by_client(pdf::DataFrame, client_type::String, data_x, data_y; 
    name="", 
    start_date=nothing, 
    end_date=nothing, regression_data = false)
    mask = (pdf."client_type" .== client_type)
    if start_date !== nothing
        sd = Date(start_date[1:10])
        cond = (pdf."date" .> sd)
        mask = (mask .& cond)
    end
    if end_date !== nothing
        ed = Date(end_date[1:10])
        cond = (pdf."date" .< ed)
        mask = (mask .& cond)
    end
    cpdf = pdf[mask,:]
    x = cpdf[:,data_x]
    y = cpdf[:,data_y]
    # Moving averages
    my = movingaverage(y,7)
    ly,β,α = linear_regression(cpdf)

    precision = 6
    β = round(β,digits= precision)
    α = round(α, digits = precision)
    total_requests = sum(y)
    μ = round(mean(y),digits=precision)
    sdev = round(sqrt(var(y)),digits=precision)
    info = [
        html_div([
            html_p("Total : $total_requests")
            html_p("Average : $μ")
            html_p("Std deviation : $sdev")
            html_p("Regression slope : $β")
            ]
        )
    ]
    if regression_data
        return scatter(x=x, y=y, mode="markers+lines", name= name), # Main plot
            scatter(x=x, y=my, mode="lines",name="μ"), # moving averages
            scatter(x=x, y=ly, mode="lines",name="L"), info
    end
    scatter(x=x, y=y, mode="markers+lines", name= name), info
end 

function plot_default()
    fig = scatter(x=[0], y=[0], mode="lines")
    plot(fig, layout)
end




function plot_graphs(options, client_type; start_date=nothing, end_date=nothing)
    if (options !== nothing) 
        if length(options) == 0 
            return plot_default(), [""]
        end
        if length(options) == 1
            options = options[1]
        end
        if typeof(options) == String
            sp,sm, sl, info = scatter_by_client(package_dataframe(options),client_type, "date", "request_count",
            start_date=start_date,
            end_date=end_date, 
            name=options, regression_data=true)
            plot_data = [sp,sm,sl]
            return plot(plot_data, layout), info
        else
            plot_data = [scatter_by_client(package_dataframe(op),client_type, 
                "date", "request_count", start_date=start_date,end_date=end_date, name=op)[1] for op in options]            
            return plot(plot_data, layout), [""]
        end
    end
    return plot_default(), [""]
end

 