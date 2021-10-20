using Pkg
Pkg.activate(".")

using Dash, DashHtmlComponents, DashCoreComponents, DashBootstrapComponents
using Statistics, DataFrames, CSVFiles
using Dates
import TOML

include("utils.jl")


# App begins
df = load_dataframe()

app = dash(external_stylesheets=[dbc_themes.COSMO])

description = dcc_markdown(
raw"This Julia Dash App shows the requests of Julia packages made by clients during period of time. 
We consider two types of requests: 

1. Those made by standard users 
2. Those that arise from continuous integration runs (ci runs)

For a given package the data is represented as curves under the *standard users* and *ci runs* tabs. We also add a seven 
day moving average curve μ and linear regression line L. It is 
possible to compare request curves for different packages by using the dropdown menu under the search controls. In 
this case (and to avoid clutter) we don't plot the moving average curves nor the regression lines.
"
)

title = dbc_row(
    dbc_col(
        dbc_jumbotron(html_center(html_h1("Julia Packages Requests")), className="bmi-jumbotron")
    ), className="mt-3",
)

users_tab = dbc_card(
    dbc_cardbody([
        html_p("This is tab 1!", className="card-text"),
        dbc_button("Click here", color="success"),
    ]),
    className="mt-3",
);

ci_tab = dbc_card(
    dbc_cardbody([
        html_p("This is tab 2!", className="card-text"),
        dbc_button("Don't click here", color="danger"),
    ]),
    className="mt-3",
);

help_tab = dbc_card(
    dbc_cardbody([
        description,
    ]),
    className="mt-3",
);


info_card = dbc_card(
    [
        dbc_cardheader("Requests Statistics")
        dbc_cardbody(
            [
                html_div(id="info-data",
                    [
                        html_p("Info Data")
                    ]
                )
            ]
        )
    ], className="card-tiny"
)

tabs = dbc_row(
    [
        dbc_col(
            html_div(
                [
                    dbc_tabs(
                        [
                            dbc_tab(label="Standard user", tab_id="user"),
                            dbc_tab(label="Ci runs", tab_id="ci"),
                            dbc_tab(label="Help", tab_id="help"),
                        ],
                        id="tabs",
                        active_tab="user",
                    ),
        html_div(id="graph-content"),
                ]
            ),width=8
        )
        dbc_col(info_card,width=4)
    ]
);


date_picker = dcc_datepickerrange(id="dates", start_date=df."date"[begin],end_date=df."date"[end])

input = dbc_row(
    [
        dbc_col(
            date_picker,
            width = 4
        ),
        dbc_col(
            dbc_input(id="search-input", placeholder="Enter package name......", type="text"),
            width = 3
        ),
        dbc_col(
            dbc_button("Seach", id="search-button", color="primary", className="mr-1"),
            width = 2
        )
    ]
)



drop = dbc_row(
    dbc_col(dcc_dropdown(id="drop",
                options = [(label = "PlotlyJS", value = "PlotlyJS")],
                multi = true,
                value = nothing
            ), width=8,

    )
)

opts = []

callback!(app, Output("drop","options"), Output("drop","value"), Output("search-input","value"), Input("search-button", "n_clicks"), State("search-input", "value")) do clicks, input_value
    package_df = package_dataframe(input_value)
    if package_df === nothing
        return opts, nothing, ""
    end
    append!(opts,[(label = input_value, value = input_value)])
    opts_set = Set(opts)
    opts_new = [o for o in opts_set]
    opts_new, input_value, ""
end

callback!(
  app, 
  Output("graph-content", "children"), 
  Output("info-data", "children"),
  Input("tabs", "active_tab"),
  Input("drop","value"),
  Input("dates","start_date"),
  Input("dates","end_date")
  )  do at, options, start_date, end_date
    if at == "user"
        figure, info = plot_graphs(options,"user",start_date=start_date, end_date=end_date)
        graph = dcc_graph(id="graph_us", figure = figure)
        return graph, info
    elseif at == "ci"
        figure, info = plot_graphs(options,"ci",start_date=start_date, end_date=end_date)
        graph = dcc_graph(id="graph_ci", figure = figure)
        return graph, info
    elseif at == "help"
        info = [""]
        return help_tab, info
    else
        html_p("This shouldn't ever be displayed..."), ["Error!"]
    end
end

app.layout = dbc_container(
    [title
    dbc_spinner(tabs)
    html_br()
    input
    html_br()
    drop]
)

run_server(app, "0.0.0.0", debug=false)