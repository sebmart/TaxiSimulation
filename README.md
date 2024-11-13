# TaxiSimulation
Tools to simulate taxi routing, used for the simulations of the OperationsResearch paper "Online Vehicle Routing: The Edge of Optiization in Large-Scale Applications".

# Update for Julia 1.x
This fork repository made minimal changes to adapt TaxiSimulation to Julia 1.x : 
- Migrate graphic structures from SFML to CSFML bindings
- Indexing and DataStructures syntax modifications
- JuMP syntax updates 
- Other modules syntax
- Type and Struct refactoring. 
This repo is not registered :(), since I haven't figured how to build a package in short learning time, will look up to it. 

# Usage
This repository contains the code of a Julia v0.5 package, that also builds on the RoutingNetworks package for real life routing network handling and visualization.
The code is provided "as is" under GNUv3 license. 

## Visualization controls:
View:
- Z - zoom in
- X - zoom out
- A - Thicker drawings
- S - Thinner drawings
- UP/DOWN/LEFT/RIGHT - move camera
- Q or ESC - quit

Time:
- SPACE - pause/play
- W - accelerate time
- E - decelerate time
- R - reverse time
