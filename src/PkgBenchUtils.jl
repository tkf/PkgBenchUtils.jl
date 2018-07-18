module PkgBenchUtils

using PkgBenchmark: judge, export_markdown
using GitHub: create_gist

function post_judge(package_name::String;
                    target = nothing,
                    baseline = "HEAD^",
                    script = nothing,
                    public = false,
                    kwargs...)

    if target === nothing
        args = (baseline,)
    else
        args = (target, baseline)
    end

    results = judge(
        package_name,
        args...;
        script = script,
        kwargs...)

    # https://juliaci.github.io/PkgBenchmark.jl/stable/export_markdown.html

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

    posted_gist = create_gist(params = gist_json)

    run(`xdg-open $(get(posted_gist.html_url))`)

    return results, posted_gist
end

end # module
