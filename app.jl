using Pkg
Pkg.activate(".")
#using RemoteFiles
using Dash, PlotlyJS
using CSVFiles
using DataFrames
using Dates
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

function scatter_by_client(pdf, client_type, data_x, data_y)
    mask = (pdf."client_type" .== client_type)
    cpdf = pdf[mask,:]
    scatter(x=cpdf[:,data_x], y=cpdf[:,data_y], mode="markers+lines", name= client_type)
end 

function plot_default()
    fig = scatter(x=[0], y=[0], mode="lines")
    plot(fig, layout)
end

graphs = html_div(style=Dict("width"=>"600px"),[
    dcc_tabs(id="graphs", value="user", children=[
        dcc_tab(label="user", value="user"),
        dcc_tab(label="ci", value="ci"),
    ]),
    html_div(id="graph_content")
])

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
        html_br(),
        html_br(),
        search_button,
        html_br(),
        html_br(),
    ]
)
date_picker = dcc_datepickerrange(
  id="date-picker-range",
  start_date=DateTime(1997, 5, 3),
  end_date_placeholder_text="Select a date!"
)

drop  = dcc_dropdown(id="drop",
        options = [
            (label = "PlotlyJS", value = "PlotlyJS"),
        ],
        multi = true,
        value = nothing
)

app.layout = html_center(
    [
        html_h1("Julia Packages"),
        html_h2("Request Statistics"),
        html_center(graphs),
        
        html_break(2),
        search_gui,
        date_picker, 
        drop,
        html_break(2)
    ]
)

opts = []

callback!(app, Output("drop","options"), Output("drop","value"), Input("search-button", "n_clicks"), State("package_input", "value")) do clicks, input_value
    package_df = package_dataframe(input_value)
    if package_df === nothing
        return opts, nothing
    end
    append!(opts,[(label = input_value, value = input_value)])
    opts,input_value
end


function plot_graphs(options, client_type)
    if options !== nothing
        if typeof(options) == String
            plot_data = [scatter_by_client(package_dataframe(options),client_type, "date", "request_count")]
            return plot(plot_data, layout)
        else
            plot_data = [scatter_by_client(package_dataframe(op),client_type, "date", "request_count") for op in options]            
            return plot(plot_data, layout)
        end
    end
    return plot_default()
end
   
callback!(
  app, Output("graph_content", "children"), 
  Input("graphs", "value"),Input("drop","value"))  do graph, options
    #println(options)
    if graph == "user"
      return dcc_graph(id="graph_us", figure = plot_graphs(options,"user"))
    else
      return dcc_graph(id="graph_ci", figure = plot_graphs(options,"ci"))
    end
end

run_server(app, "0.0.0.0", debug=true)

 
 