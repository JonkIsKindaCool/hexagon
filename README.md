
# HEXAGON

A Simple build tool for haxe, inspired in lime's configuration file (Project.xml)


## Setup

First you need to install the library, using 
```
haxelib install hexagon
```
Then you need to setup the command alias (hexagon)
```
haxelib run hexagon setup
```
## Usage
Hexagon only has 2 commands 
```
haxegon build (target) [-defines]
``` 
and 
```
hexagon test (target) [-defines]
``` 

The supported targets are `hl` `js` `neko` `windows` `mac` `linux` `cs` `java` `py` `lua` `interp`, the default targets of haxe.

The Main entry point class should be something like
```haxe
package;

class Main {
    public function new(){
        //do your things here
    }
}
``` 
You need a hexagon.json file in your project
## Build Parameters
```
name: String
version: String
author: String

paths:
    source: String Array
    assets: String Array
    export: String
build:
    debug (optional): Boolean
    verbose (optional): Boolean
    optimize (optional): Boolean
    main: String
    dce (optional): String

dependencies: Dependencies Array {name: String, version (optional): String}
defines: String Array
macros: String Array
```