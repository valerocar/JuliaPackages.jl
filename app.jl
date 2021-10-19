using Pkg
Pkg.activate(".")
#using RemoteFiles
using Dash, PlotlyJS
using CSVFiles
using DataFrames
using Dates
using Revise
using Statistics
import TOML

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

function html_break(n)
    html_div([html_br() for i = 1:n])
end

function load_dataframe(file_name)
    #stats_base = "https://julialang-logs.s3.amazonaws.com/public_outputs/current"
    #r = RemoteFile(stats_base*"/"*file_name, dir=".")
    #download(r)
    DataFrame(load(File(format"CSV", "./package_requests_by_date.csv.gz")))
end


# App begins
df = load_dataframe("package_requests_by_date.csv.gz")

function package_dataframe(package_name::String)
    result = lookup(package_name)
    if length(result) > 0
        uuid = string(result[1])
        mask = ((df."package_uuid" .== uuid) .& (df."status" .== 200))
        return df[mask,:]
    end
    nothing
end

layout = Layout(;title="",width=600, height=400, xaxis=attr(title="Date"), yaxis=attr(title="Requests Count"))


function linear_regression(df)
    days = df."date"-df."date"[begin]
    daysi = [Dates.value(d) for d in days] # Days as integers
    reqs = df."request_count"

    md = mean(daysi) # Mean for days
    mr = mean(reqs) # Mean for requests

    β = sum((daysi .-md).*(reqs .-mr))/sum((daysi .-md).*(daysi .-md))
    α = mr -β*md
    return β.*daysi.+α
end


function scatter_by_client(pdf, client_type, data_x, data_y; 
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
    ly = linear_regression(cpdf)
    if regression_data
        return scatter(x=x, y=y, mode="markers+lines", name= name), # Main plot
            scatter(x=x, y=my, mode="lines",name="μ"), # moving averages
            scatter(x=x, y=ly, mode="lines",name="L")
    end
    scatter(x=x, y=y, mode="markers+lines", name= name)
end 


function plot_default()
    fig = scatter(x=[0], y=[0], mode="lines")
    plot(fig, layout)
end 

graphs = dcc_loading(html_div(style=Dict("width"=>"600px"),[
    dcc_tabs(id="graphs", value="user", children=[
        dcc_tab(label="standard users", value="user"),
        dcc_tab(label="ci runs", value="ci"),
    ]),
    html_div(id="graph_content")
]))

search_button = html_button("Search", id="search-button", n_clicks=0)

app = dash()

package_input = dcc_input(
        id = "package_input",
        placeholder="Enter package name...",
        type="text",
        value=""
    )

search_gui = html_div(
    [
        package_input,
        search_button,
    ]
)
date_picker = dcc_datepickerrange(
  id="dates",
  start_date=df."date"[begin],
  end_date=df."date"[end],
)

drop  = dcc_dropdown(id="drop",
        options = [
            (label = "PlotlyJS", value = "PlotlyJS"),
        ],
        multi = true,
        value = nothing
)


description = dcc_markdown(
raw"This Julia Dash App shows the requests of Julia packages made by clients during period of time. 
We consider two types of requests: 

1. Those made by standard users 
2. Those that arise from continuous integration runs (ci runs)

For a given package the data is represented as curves under the *standard users* and *ci runs* tabs. We also add a 7 
day moving average curve μ and linear regression line L. It is 
possible to compare request curves for different packages by using the dropdown menu under the search controls. In 
this case (and to avoid clutter) we don't plot the moving average curves nor the regression lines.
"
)


app.layout = html_div(
    [
        html_center(
            [
                html_h1("Julia Packages Requests"),
            ]
        ),
        html_break(1),
        html_center(html_div(style = Dict("width"=>"600px","text-align"=>"left"),description)),
        html_break(1),
        html_center(
         [  
            html_center(graphs),
            html_break(1),
            date_picker, 
            html_break(1),
            search_gui,
            html_break(1),
            html_div(style=Dict("width"=>"500px"),drop),
            html_break(3)
    ]
)

    ]
)
 

opts = []

callback!(app, Output("drop","options"), Output("drop","value"), Input("search-button", "n_clicks"), State("package_input", "value")) do clicks, input_value
    package_df = package_dataframe(input_value)
    if package_df === nothing
        return opts, nothing
    end
    append!(opts,[(label = input_value, value = input_value)])
    opts_set = Set(opts)
    opts_new = [o for o in opts_set]
    opts_new,input_value
end

function plot_graphs(options, client_type; start_date=nothing, end_date=nothing)
    if (options !== nothing) 
        if length(options) == 0 
            return plot_default()
        end
        if length(options) == 1
            options = options[1]
        end
        if typeof(options) == String
            sp,sm, sl = scatter_by_client(package_dataframe(options),client_type, "date", "request_count",
            start_date=start_date,
            end_date=end_date, 
            name=options, regression_data=true)
            plot_data = [sp,sm,sl]
            return plot(plot_data, layout)
        else
            plot_data = [scatter_by_client(package_dataframe(op),client_type, 
                "date", "request_count", start_date=start_date,end_date=end_date, name=op) for op in options]            
            return plot(plot_data, layout)
        end
    end
    return plot_default()
end
    
callback!(
  app, Output("graph_content", "children"), 
  Input("graphs", "value"),
  Input("drop","value"),
  Input("dates","start_date"),
  Input("dates","end_date")
  )  do graph, options, start_date, end_date
    if graph == "user"
      return dcc_graph(id="graph_us", figure = plot_graphs(options,"user",start_date=start_date, end_date=end_date))
    else
      return dcc_graph(id="graph_ci", figure = plot_graphs(options,"ci",start_date=start_date, end_date=end_date))
    end
end

run_server(app, "0.0.0.0", debug=true)

 
 