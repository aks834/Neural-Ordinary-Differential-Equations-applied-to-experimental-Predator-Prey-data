# Overview
The goal of this project is to use Neural networks integrated into Differential equations an an attempt to capture complexity in a predator-prey relationship. Model1.jl is a replication of Blasius et al's mathematical model for the specific predator-prey relationship(planktonic rotifers and unicellular green algae). Details can be found at: https://doi.org/10.1038/s41586-019-1857-0
A standard Lotka-Volterra approach will be compared to a hybrid NODE approach.

# Julia
All programs in this project are written in julia. To install julia on your machine follow the instructions at: https://julialang.org/downloads/
Alternatively, execute:

```
curl -fsSL https://install.julialang.org | sh 
```

in command line to install julia v1.10.4 .

# Data
'''C1.csv''' is a CSV file containing experimentally determined predator-prey population data from a chemostat experiment. Data available for download at: https://figshare.com/articles/dataset/Time_series_of_long-term_experimental_predator-prey_cycles/10045976/1

Data_load.jl can be used to visualize the initial data. In the file, the desired csv file can be changed. To run the program in command line, execute

```
julia data_load.jl
```

This will load a visualization of what is is C1 in a file called 

```C1_plot.png``` 

The program ``data_filter_to_dat.jl`` can be used to turn the time, algae(10^6 cells/ml), and rotifers(animals/ml) elements into a dat file. To run the program in commant line, execute: 

```
julia data_filter_to_dat.jl
``` 

The output of this program is ```ProcessedData.dat```, which is accessible via the ```data``` folder.

# Models
```Neural_diff-equation_approach.jl``` is the hybrid-node model to predict population dynamics. It integrates a neural network for two of the terms in the Lotka-Volterra equations. Based on Chritopher Rackaucas' implementation at: https://github.com/ChrisRackauckas/universal_differential_equations/tree/master
To run in command line, execute: 

```
julia Neural_diff-equation_approach.jl
```

```Standard_lotka_volterra.jl``` is a standard lotka-volterra model. To run it, execute:

```
Standard_lotka_volterra.jl
```

```NODE_Artificial_Data.jl``` is a model which trains off of noisy lotka volterra data to in order to determine whether or not the integrated neural network can match the fit of population flucuations. To run it, execute: 
```
NODE_Artificial_Data.jl
```
