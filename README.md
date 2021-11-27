# JuliaPackages.jl

This Julia-Dash App produces graphs of the request statistics for Julia Packages. It uses the [data warehouse](https://discourse.julialang.org/t/announcing-package-download-stats/69073) by Stefan Karpinski and Elliot Saba. Many thanks to them for making the existence of this App possible.

![Julia Packages App](JuliaPackages.gif)

You can run the app from the command line & Julia REPL by typing

```
$ git clone https://github.com/valerocar/JuliaPackages.jl
$ cd JuliaPackages.jl
$ julia
julia> using Pkg
julia> Pkg.activate(".")
julia> Pkg.instantiate()
julia> include("app.jl")
```

and then opening your browser at http://localhost:8050/

You can find a Heroku deployment of this app at https://julia-packages-app.herokuapp.com/
