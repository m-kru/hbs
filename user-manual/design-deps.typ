= Fetching and managing design dependencies

A lot of modern software programming languages come with official package and dependency management tools.
For example, `pip` for Python, `npm` for Node.js, `cargo` for Rust.
In the hardware design domain, there was never any official package and dependency manager.
Keeping dependencies in-tree is de facto the standard way.
In practice, people just manually or  semi-automatically copy dependencies to the project sources.
The dependency sources are kept in the tree of the project directory, hence the term "in-tree".
Keeping dependencies in-tree forces you to be conscious about what is included in the project.
It also helps to avoid bloat.

HBS currently does not have any mechanism for fetching design dependencies.
This is because different dependencies might require completely different commands to be executed to fetch them and prepare them for use.
Some teams like to manage external dependencies using git submodules.
Others prefer to copy dependencies manually.
Yet others implement custom shell or Python scripts.
HBS does not try to limit or impose anything on the user in this matter.

Although HBS does not provide any mechanism for fetching and managing design dependencies, nothing stops you from implementing such a mechanism in hbs files.
You can use target procedures for that purpose if you want to track these dependencies in the target dependency graph, or you can simply define Tcl procedures outside core namespaces.
