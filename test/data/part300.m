function mpc = part300
%CASE300    Power flow data for IEEE 300 bus test case.
%   Please see CASEFORMAT for details on the case file format.
%   This data was converted from IEEE Common Data Format
%   (ieee300cdf.txt) on 18-Nov-2014 by cdf2matp, rev. 2393
%   See end of file for warnings generated during conversion.
%
%   Converted from IEEE CDF file from:
%       https://labs.ece.uw.edu/pstca/
% 
%  13/05/91 CYME INTERNATIONAL    100.0 1991 S IEEE 300-BUS TEST SYSTEM

%   MATPOWER

%% MATPOWER Case Format : Version 2
mpc.version = '2';

%%-----  Power Flow Data  -----%%
%% system MVA base
mpc.baseMVA = 100;

%% bus data
%	bus_i	type	Pd	Qd	Gs	Bs	area	Vm	Va	baseKV	zone	Vmax	Vmin
mpc.bus = [
	152	3       17	9       0	0       1       1.0535	9.24	230     1	1.06	0.94;
	153	2       0	0       0	0       1       1.0435	10.46	230     1	1.06	0.94;
	154	1       70	5       0   34.5	1       0.9663	-1.8	115     1	1.06	0.94;
	155	1       200	50      0	0       1       1.0177	6.75	230     1	1.06	0.94;
	156	1       75	50      0	0       1       0.963	5.15	115     1	1.06	0.94;
	161	1       35	15      0	0       1       1.036	8.85	230     1	1.06	0.94;
	164	1       0	0       0	-212	1       0.9839	9.66	230     1	1.06	0.94;
	183	1       40	4       0	0       1       0.9717	7.12	115     1	1.06	0.94;
];

%% generator data
%	bus	Pg	Qg	Qmax	Qmin	Vg	mBase	status	Pmax	Pmin	Pc1	Pc2	Qc1min	Qc1max	Qc2min	Qc2max	ramp_agc	ramp_10	ramp_30	ramp_q	apf
mpc.gen = [
	152	372	0	175	-50	1.0535	100	1	472	0	0	0	0	0	0	0	0	0	0	0	0;
	153	216	10	90	-50	1.0435	100	1	316	0	0	0	0	0	0	0	0	0	0	0	0;
    153	206	30	90	-50	1.0435	100	1	316	0	0	0	0	0	0	0	0	0	0	0	0;
];

%% branch data
%	fbus	tbus	r	x	b	rateA	rateB	rateC	ratio	angle	status	angmin	angmax
mpc.branch = [
    164	155	0.0009	0.0231	-0.033	10	0	0	0.956	10.2	1	-360	360;
    155	156	0.0008	0.0256	0	0	0	0	1.05	0	1	-360	360;
    154	156	0.1746	0.3161	0.04	0	0	0	0	0	1	-360	360;
    155	161	0.011	0.0568	0.388	0	5	0	0	0	1	-360	360;
    153	183	0.0027	0.0639	0	0	0	0	1.073	0	1	-360	360;
    153	161	0.0055	0.0288	0.19	0	0	0	0	0	1	-360	360;
    152	153	0.0137	0.0957	0.141	0	0	0	0	0	1	-360	360;
    154	183	0.0804	0.3054	0.045	0	0	3	0	0	1	-360	360;
];

%%-----  OPF Data  -----%%
%% generator cost data
%	1	startup	shutdown	n	x1	y1	...	xn	yn
%	2	startup	shutdown	n	c(n-1)	...	c0
mpc.gencost = [
	2	0	0	3	0.01	40	0;
	2	0	0	3	0.0266666667	20	0;
    2	0	0	3	0.0266666667	20	0;
];