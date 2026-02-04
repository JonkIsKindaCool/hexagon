package hexagon.data;

import haxe.extern.EitherType;

typedef HexagonData = {
	name:String,
	version:String,
	author:String,
    paths: HexagonPaths,
    build: HexagonBuild,
    dependencies: HexagonDependencies,
    ?defines: Array<String>,
    ?macros: Array<String>
}

typedef HexagonPaths = {
    source: Array<String>,
    assets: Array<String>,
    export: String
}

typedef HexagonDependencies = Array<HexagonDependency>;

typedef HexagonDependency = {
    name:String,
    ?version:String
}

typedef HexagonBuild = {
    ?debug:Bool,
    ?verbose:Bool,
    ?optimize:Bool,
    main:String,
    ?dce:String
}