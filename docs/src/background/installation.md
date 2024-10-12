# [Installation Guide](@id InstallationGuide)
JuliaGrid is compatible with Julia version 1.9 and later. To get started with JuliaGrid, users should first install Julia and consider using a code editor for a smoother coding experience.

---

## Install Julia
Begin by [downloading and installing](https://julialang.org/downloads/) Julia. We can choose either the Current Stable Release or the Long-term Support Release.

The Current Stable Release is the most recent version of Julia, providing access to the latest features and typically offering better performance. For most users, we recommend installing the Current Stable Release. The Long-term Support Release is an older version of Julia that has continued to receive bug and security fixes. However, it may not have the latest features or performance improvements.

---

## Install Code Editor
For a smoother development experience, we recommend using a code editor. While you can write Julia code in any text editor, using an integrated development environment (IDE) makes coding easier and more efficient. We suggest installing [Visual Studio Code](https://code.visualstudio.com/), which provides excellent support for Julia through its dedicated Julia extension. Visual Studio Code offers features like syntax highlighting, debugging, and autocompletion, making it an ideal choice for both beginners and experienced users.

The [Julia extension](https://marketplace.visualstudio.com/items?itemName=julialang.language-julia) for Visual Studio Code includes built-in dynamic autocompletion, inline results, plot pane, integrated REPL, variable view, code navigation, and many other advanced language features.  For a step-by-step guide on how to use Julia in Visual Studio Code, you can follow the tutorial available [here](https://code.visualstudio.com/docs/languages/julia).

---

## Install JuliaGrid
To get the JuliaGrid package installed, execute the following Julia command:
```julia
import Pkg
Pkg.add("JuliaGrid")
```

When a new version of JuliaGrid is released, you can update it with the following command:
```julia
import Pkg
Pkg.update("JuliaGrid")
```