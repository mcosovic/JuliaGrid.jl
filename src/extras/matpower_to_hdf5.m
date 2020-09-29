clc
clearvars

%--------------------------------------------------------------------------
% Builds the power system data from Matpower input file
%
% Load Matpower test case as the variable 'mpc' (see line 22). Matpower 
% input m-file should be in the same directory as this m-file.
%--------------------------------------------------------------------------
%  Input:
%	- Matpower test case
%
%  Output:
%	- HDF5 file: power system data compatible with the JuliaGrid 
%--------------------------------------------------------------------------
% Created by Mirsad Cosovic on 03-06-2020
% Last revision by Mirsad Cosovic on 03-06-2020
% JuliaGrid is released under MIT License.
%--------------------------------------------------------------------------


%---------------------------Load Matpower Case-----------------------------
 mpc = case14test;
 name = 'case14test';
%--------------------------------------------------------------------------


%------------------------------Bus Data------------------------------------
 name = join([name, '.h5']);
 
 [Nbus, Ncol] = size(mpc.bus);
 h5create(name, '/bus', [Nbus Ncol]);
 h5write(name, '/bus', mpc.bus);
%--------------------------------------------------------------------------


%----------------------------Branch Data-----------------------------------
 [Nbranch, Ncol] = size(mpc.branch);
 h5create(name, '/branch', [Nbranch Ncol + 1])
 h5write(name, '/branch', [(1:Nbranch)' mpc.branch])
%--------------------------------------------------------------------------


%---------------------------Generator Data---------------------------------
[Ngen, Ncol] = size(mpc.gen);
h5create(name, '/generator', [Ngen Ncol])
h5write(name, '/generator', mpc.gen)
%--------------------------------------------------------------------------


%------------------------Generator Cost Data-------------------------------
[Ngen, Ncol] = size(mpc.gencost);
h5create(name, '/generatorcost', [Ngen Ncol])
h5write(name, '/generatorcost', mpc.gencost)
%--------------------------------------------------------------------------


%--------------------------Base Power Data---------------------------------
 h5create(name, '/basePower', 1)
 h5write(name, '/basePower', mpc.baseMVA)
%--------------------------------------------------------------------------