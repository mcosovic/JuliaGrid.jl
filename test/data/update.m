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
	1	3       30	0      10	-20      1       1.00	 0.0	230     1	0.0 	0.0;
	2	1       0	20      0	 0       1       1.20	 0.0	120     1	0.0     0.9;
	4	1       70	5       0    30      1       1.00	 0.0	230     1	0.0     0.0;
	5	1       200	50      0	 0       2       1.00	-0.8	230     3	0.0     0.0;
	6	1       75	50      0	 0       1       1.00	 0.0	115     1	0.0     0.0;
	7	1       35	15      0	 0       1       0.90	 0.0	230     1	1.06	0.0;
	8	1       0	0       0	-10 	 1       0.98	 7.1	230     1	1.20	0.80;
	9	1       40	4       0	 0       1       1.00	 0.0	115     1	0.0     0.0;
];

%% generator data
%	bus	Pg	Qg	Qmax	Qmin	Vg	mBase	status	Pmax	Pmin	Pc1	Pc2	Qc1min	Qc1max	Qc2min	Qc2max	ramp_agc	ramp_10	ramp_30	ramp_q	apf
mpc.gen = [
	1	370  0	90	-10	1.0	100	0	100	10	100	500	200	300	300	400	500	300	0	400	0;
	2	210	 0	90	-50	1.2	100	1	316	0	0	0	0	0	0	0	0	0	0	0	0;
    2	30	10	90	-50	1.0	100	0	316	0	0	0	0	0	0	0	0	0	0	0	0;
	1	10  20	90	-50	1.0	100	1	0	0	0	0	0	0	0	0	0	0	0	0	0;    
];

%% branch data
%	fbus	tbus	r	x	b	rateA	rateB	rateC	ratio	angle	status	angmin	angmax
mpc.branch = [
    8	5	0.05	0.02	0   	0	0	0	0.89	1.2     0	0	360;
    5	6	0.09	0.02	0       0	0	0	1.05	0       0	0	360;
    4	6	0.17	0.31	0.10	0	0	0	0       0       1	0	360;
    5	7	0.01	0.05	0.14	0	5	0	0       0       1	0	360;
    2	9	0.09	0.06	0       0	0	0	1.073	0       1	0	360;
    2	7	0.08	0.04	0.14	0	0	0	0       0       1	0	360;
    1	2	0.07	0.09	0.14	500	200	400	0       0       1	0	360;
    4	9	0.08	0.30	0.14	0	0	3	0       0       1  -2	1;
];

%%-----  OPF Data  -----%%
%% generator cost data
%	1	startup	shutdown	n	x1	y1	...	xn	yn
%	2	startup	shutdown	n	c(n-1)	...	c0
mpc.gencost = [
	2	0	0	3	0.01	40	4;
	2	0	0	3	0.0266666667	20	3;
    2	0	0	3	0.0266666667	20	2;
    2	0	0	3	0.3	15 5;
];