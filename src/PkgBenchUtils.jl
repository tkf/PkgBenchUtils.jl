module PkgBenchUtils

using PkgBenchmark: judge, export_markdown
using Setfield
import GitHub

include("ir_dump.jl")

struct Results
    results
    script
    posted

    Results(results, script = nothing, posted = nothing) =
        new(results, script, posted)
end

function Base.show(io::IO, r::Results)
    print(io, "PkgBenchUtils.Results")
    if r.script !== nothing
        print(io, " [", r.script, "]")
    end
    println(io)
    if r.posted !== nothing
        println(io, "URL: ", url(r))
    end
    show(io, r.results)
end

guess_package() = basename(pwd())

_common_docs = """
- `config::Union{Nothing, BenchmarkConfig}`: Configuration to be used
  if `target` or `baseline` is a `String`.
- `target`: Default to `"HEAD"`.  (Passed to `PkgBenchmark.judge`)
- `baseline`: Default to `"HEAD^"`.  (Passed to `PkgBenchmark.judge`)
- `script::String`: Script from which benchmark `SUITE` is loaded.
  (Passed to `PkgBenchmark.judge`)
- Other keyword arguments are also passed to `PkgBenchmark.judge`.
"""

"""
    _judge([pkg::String]; <keyword arguments>) :: Results

# Keyword Arguments
$_common_docs
"""
function _judge(package_name::String = guess_package();
                config = nothing,
                target = "HEAD",
                baseline = "HEAD^",
                script = nothing,
                kwargs...)

    if config !== nothing
        (target isa String) && (target = @set config.id = target)
        (baseline isa String) && (baseline = @set config.id = baseline)
    end

    return Results(
        judge(package_name, target, baseline;
              script = script,
              kwargs...),
        script,
    )
end

as_markdown(results::Results) = as_markdown(results.results)

function as_markdown(results)
    io = IOBuffer()
    export_markdown(io, results)
    seek(io, 0)
    return Markdown.parse(io)
end

"""
    show_judge([pkg::String]; <keyword arguments>) :: Results

# Keyword Arguments
$_common_docs
"""
function show_judge(args...; kwargs...)
    results = _judge(args...; kwargs...)
    println()
    display(as_markdown(results))
    println()
    return results
end

_post_docs = """
- `auth`: authentication object created by `GitHub.authenticate`.
  Default to `GitHub.authenticate(ENV["PKGBENCHUTILS_GITHUB_AUTH"])`.
- `public::Bool`: post to public gist if true.
"""

"""
    post_results(results::Results; <keyword arguments>) :: Results

https://juliaci.github.io/PkgBenchmark.jl/stable/export_markdown.html

# Keyword Arguments
$_post_docs
"""
function post_results(results::Results; kwargs...)
    posted = post_results(results.results, results.script; kwargs...)
    return @set results.posted = posted
end

function post_results(results, script;
                      auth = GitHub.authenticate(ENV["PKGBENCHUTILS_GITHUB_AUTH"]),
                      public = false,
                      kwargs...)
    package_name = results.baseline_results.name

    gist_json = Dict(
        :description => "A benchmark for $package_name",
        :public => public,
        :files => Dict(
            "benchmark.md" => Dict(
                :content => sprint(export_markdown, results),
            ),
        )
    )
    if script !== nothing
        gist_json[:files]["script.jl"] = Dict(
            :content => readstring(script),
        )
    end

    return GitHub.create_gist(params = gist_json;
                              auth = auth,
                              kwargs...)
end

"""
    post_judge([pkg::String]; <keyword arguments>) :: Results

Run `judge` and then `post_results`.

# Keyword Arguments
- `open::Bool`: open posted gist in browser.
$_post_docs
$_common_docs
"""
function post_judge(args...;
                    auth = GitHub.authenticate(ENV["PKGBENCHUTILS_GITHUB_AUTH"]),
                    public = false,
                    open = false,
                    kwargs...)

    results = _judge(
        args...;
        kwargs...)

    results = post_results(results; public=public, auth=auth)
    if open
        open_url(results)
    end

    return results
end

url(results) = get(results.posted.html_url)
open_url(results) = run(`xdg-open $(url(results))`)

end # module
