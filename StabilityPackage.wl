(* ::Package:: *)

BeginPackage["StabililtyPackage`"]

ImportData::usage =
	"ImportData[file] reads in the data from file."
buildHamiltonians::usage=
	"Return elements of the hamiltonians"
getEquations::usage=
	"Return the equations of motions"
rules::usage=
	"Some substitution rules"
stabilityMatrix::usage=
	"returns the stability matrix"
evscale::usage=
	"solves for the eigenvalues"
SCalcScale::usage=
	"Computes several things"
buildkGrid::usage=
	"constructions the adaptive k grid"
kAdapt::usage=
	"runs the full routine"
	

Begin["`Private`"]

(*This function imports file with path name "infile" at radial bin ri, and creates associations for parts of the data.
Format to call: dataname=ImportData[infile,1]["keyword"][[index]]
*)
ImportData[infile_]:=ImportData[infile]=
Association[
"lotsodo"->Import[infile,{"Data","distribution(erg|ccm,lab)"}] (*distribution functions*),
"matters"->Import[infile,{"Data","rho(g|ccm,com)"}], (*densities*)
"Yes"->Import[infile,{"Data","Ye"}], (*electron fractions *)
"freqs"->Import[infile,{"Data", "distribution_frequency_grid(Hz,lab)"}], (*freq grid in hz*)
"freqmid"->Import[infile,{"Data", "distribution_frequency_mid(Hz,lab)"}], (*freq mid points*)
"muss"->Import[infile,{"Data", "distribution_costheta_grid(lab)"}], (*Cos\[Theta] grid*)
"mids"->Import[infile,{"Data", "distribution_costheta_mid(lab)"}], (*Cos\[Theta] bin midpoints*)
"radius"-> Import[infile,{"Data","r(cm)"}]
];

(*This function creates the hamiltonians based on the data set, and returns them in a "general" way that is readable.  
Returns 9 arguments with index,
1,3,5,7 = H,\[Rho],A,\[Delta]H
2,4,6,8 = Hb,\[Rho]b,Ab,\[Delta]Hb
9=HsiRadial
*)
buildHamiltonians[data_,ri_,testE_,hi_]:=buildHamiltonians[data,ri,testE,hi]=Module[{n,\[Theta],name11,name12,name21,name22,\[Rho],\[Rho]b,A,Ab,Hm,Hvac,\[Mu],\[Mu]b,Hsi,H,Hb,\[Delta]H,\[Delta]Hb,nudensity,nubardensity,Ve,\[Omega],HsiRad},(

Ve=munits/mp *data["Yes"][[ri]]  *data["matters"][[ri]];
\[Omega]=\[Omega]EMev[testE];

name11="ee";
name12="ex";
name21="xe";
name22="xx";

n=Length[data["mids"]];
\[Theta]=ArcCos[data["mids"]];

Do[
\[Rho][i]={{ToExpression[StringJoin["\[Rho]",name11,ToString[i]]],ToExpression[StringJoin["\[Rho]",name12,ToString[i]]]},{ToExpression[StringJoin["\[Rho]",name21,ToString[i]]],ToExpression[StringJoin["\[Rho]",name22,ToString[i]]]}};
\[Rho]b[i]={{ToExpression[StringJoin["\[Rho]b",name11,ToString[i]]],ToExpression[StringJoin["\[Rho]b",name12,ToString[i]]]},{ToExpression[StringJoin["\[Rho]b",name21,ToString[i]]],ToExpression[StringJoin["\[Rho]b",name22,ToString[i]]]}};
A[i]={{0,ToExpression[StringJoin["A",name12,ToString[i]]]},{ToExpression[StringJoin["A",name21,ToString[i]]],0}};
Ab[i]={{0,ToExpression[StringJoin["Ab",name12,ToString[i]]]},{ToExpression[StringJoin["Ab",name21,ToString[i]]],0}};
,{i,1,n}];


nudensity[dt_]:= Sum[Sum[data["lotsodo"][[ri,1,f,dt,dp]]/ (h (data["freqmid"][[f]]) (Abs[data["muss"][[dt+1]]-data["muss"][[dt]]])),{f,1,Length[data["freqs"]]-1}],{dp,1,2}];
nubardensity[dt_]:= Sum[Sum[data["lotsodo"][[ri,2,f,dt,dp]]/ (h (data["freqmid"][[f]]) (Abs[data["muss"][[dt+1]]-data["muss"][[dt]]])),{f,1,Length[data["freqs"]]-1}],{dp,1,2}];

Hm={{Ve,0.},{0.,0.}};
Hvac=hi{{-\[Omega]/2,0.},{0.,\[Omega]/2}};
\[Mu]=munits Table[nudensity[i]*(data["muss"][[i+1]]-data["muss"][[i]]),{i,1,n},{j,1,n}];
\[Mu]b=munits Table[nubardensity[i]*(data["muss"][[i+1]]-data["muss"][[i]]),{i,1,n},{j,1,n}];


Do[
Hsi[j]=Sum[\[Mu][[k,j]]\[Rho][k](2Pi)(1-Cos[\[Theta][[j]]]Cos[\[Theta][[k]]]),{k,1,n}]+Sum[-\[Mu]b[[k,j]]\[Rho]b[k](2Pi)(1-Cos[\[Theta][[j]]]Cos[\[Theta][[k]]]),{k,1,n}];
,{j,1,n}];
Do[
H[i]=Hvac+Hm+Hsi[i];
Hb[i]=Hvac-Hm-Hsi[i];
\[Delta]H[i]=Sum[((D[H[i][[1,2]],\[Rho][j][[1,2]]]) A[j])+((D[H[i][[1,2]],\[Rho]b[j][[1,2]]])Ab[j]),{j,1,n}];
\[Delta]Hb[i]=Sum[((D[Hb[i][[1,2]],\[Rho][j][[1,2]]])A[j])+((D[Hb[i][[1,2]],\[Rho]b[j][[1,2]]])Ab[j]),{j,1,n}];
,{i,1,n}];

HsiRad=(Tr[\[Mu]]+Tr[\[Mu]b]);

Return[{H,Hb,\[Rho],\[Rho]b,A,Ab,\[Delta]H,\[Delta]Hb,HsiRad}]
)
];


(*Calculates the equations of motion by computing the relvant commutators. 
 Returns 5 arguments with index,
 1,3= neutrino equations of motion, A
 2,4 = Antineutrino equations of motion, Ab
 5=HsiRadial
 *)
getEquations[data_,ri_,testE_,hi_,k_]:=getEquations[data,ri,testE,hi,k]=Module[{n,\[Theta],eqn,eqnb,hs},( 
hs=buildHamiltonians[data,ri,testE,hi];
n=Length[data["mids"]];
\[Theta]=ArcCos[data["mids"]];
(*This could be replaced with a mapthread or with associations, but one step at time*)
With[{H=hs[[1]],Hb=hs[[2]],\[Rho]=hs[[3]],\[Rho]b=hs[[4]],A=hs[[5]],Ab=hs[[6]],\[Delta]H=hs[[7]],\[Delta]Hb=hs[[8]]}, 

Do[
eqn[j]=Com[H[j],A[j]][[1,2]]+ Com[\[Delta]H[j],\[Rho][j]][[1,2]]+(k Cos[\[Theta][[j]]] A[j][[1,2]]);
eqnb[j]=-Com[Hb[j],Ab[j]][[1,2]]- Com[\[Delta]Hb[j],\[Rho]b[j]][[1,2]]+(k Cos[\[Theta][[j]]] Ab[j][[1,2]]);
,{j,1,n}];

Return[{eqn,eqnb,A,Ab,hs[[9]]}]
](*Close with*)
)
];


(*Substitution rules to change "named" density matrix components with initial flavor state*)

rules[n_]:=Module[{r1,r2,r3,r4,rb1,rb2,rb3,rb4,rrules},( 
r1=Table[ToExpression["\[Rho]ee"<>ToString[i]]-> 1.,{i,1,n}];
r2=Table[ToExpression["\[Rho]ex"<>ToString[i]] -> 0.,{i,1,n}];
r3=Table[ToExpression["\[Rho]xe"<>ToString[i]]-> 0.,{i,1,n}];
r4=Table[ToExpression["\[Rho]xx"<>ToString[i]]-> 0.,{i,1,n}];

rb1=Table[ToExpression["\[Rho]bee"<>ToString[i]]-> 1.,{i,1,n}];
rb2=Table[ToExpression["\[Rho]bex"<>ToString[i]]-> 0.,{i,1,n}];
rb3=Table[ToExpression["\[Rho]bxe"<>ToString[i]]-> 0.,{i,1,n}];
rb4=Table[ToExpression["\[Rho]bxx"<>ToString[i]]-> 0.,{i,1,n}];

rrules=Flatten[{r1,r2,r3,r4,rb1,rb2,rb3,rb4}];
Return[rrules];
);
];

(*Generates the stability matrix for file infile, radial bin ri, vacuum energy scale testE, mass ordering hi=1 (NO) or -1 (IO), and wavenumber k.
Returns 2 arguments,
1=Stability Matrix
2=HsiRadial
*)
stabilityMatrix[data_,ri_,testE_,hi_,k_]:=Module[{S1,S2,S3,S4,S,hs,ea,n,HsiRad}, 
ea=getEquations[data,ri,testE,hi,k];
n=Length[data["mids"]];

With[{eqn=ea[[1]],eqnb=ea[[2]],A=ea[[3]],Ab=ea[[4]]},

S1=Table[Coefficient[eqn[l],A[m][[1,2]]],{l,1,n},{m,1,n}];
S2=Table[Coefficient[eqn[l],Ab[m][[1,2]]],{l,1,n},{m,1,n}];
S3=Table[Coefficient[eqnb[l],A[m][[1,2]]],{l,1,n},{m,1,n}];
S4=Table[Coefficient[eqnb[l],Ab[m][[1,2]]],{l,1,n},{m,1,n}];
S=ArrayFlatten[{{S1,S2},{S3,S4}}]/.rules[n];
HsiRad=ea[[5]]/.rules[n];
Return[{S,HsiRad}];
]
];


(*This scales the stability matrix up to a more managable scale based on the machine prescision, Solves for the eigenvalues, and then scales backs.  Returns a list of eigenvalues*)
evscale[data_,ri_,testE_,hi_,ktest_]:=Module[{\[Epsilon],A,As,kx0s,as,kx,kxs},
\[Epsilon]=$MachineEpsilon/2;
A=stabilityMatrix[data,ri,testE,hi,kx][[1]];
As=Expand[(A/\[Epsilon])/.kx->\[Epsilon] kxs];
kx0s=ktest/\[Epsilon];
as=\[Epsilon] Eigenvalues[N[As]/.kxs->kx0s];
(*bs=\[Epsilon] Eigenvalues[As]/.kxs\[Rule]kx0s;*)
Return[as]
];


(*The heavy lifter, computes several items for a single radial bin. This function returns 4 arguments,
1 = ordered list of imaginary parts of the eigenvalues of the stab. matrix, from greatest to least
2 = The radial component of the self interaction potential
3 = The stability matrix S
4 = The "target" k value for this stability matrix.  Solve for the k value that makes S[[1,1]]\[Equal]0
*)
SCalcScale[data_,ri_,testE_,hi_,ktest_]:=Module[{evalsl,pot,mat,kt,S},(
(*stabilityMatrix[infile_,ri_,testE,hi_,k_]*)
(*Create list of eigenvalues of S. Instability freqs*)
evalsl=Sort[Im[evscale[data,ri,testE,hi,ktest]],Greater];
S=stabilityMatrix[data,ri,testE,hi,kvar];
pot=S[[2]]/.kvar->ktest;
mat=S[[1]]/.kvar->ktest;
Return[{evalsl,pot,mat}]; 
);
];

(*Constructs a nstep sized log spaced k grid based on the target k associated with the infile at radial bin r.  Currently the limits are 2 orders of magnitude above and below the target value, ignoring negatives for the moment *)
buildkGrid[data_,ri_,testE_,hi_,nstep_]:=Module[{ktarget,kgrid,fspace,S0},
fSpace[min_,max_,steps_,f_: Log]:=InverseFunction[ConditionalExpression[f[#],min<#<max]&]/@Range[f@min,f@max,(f@max-f@min)/(steps-1)];
S0=SCalcScale[data,ri,testE,hi,0.][[3]];
ktarget=S0[[1,1]];
kgrid=Join[fSpace[ktarget*10^-1,ktarget*10^1,nstep],-fSpace[ktarget*10^-1,ktarget*10^1,nstep/2]];
Return[kgrid];
];

(*Run buildkGrid and SCalcScale for several radial bins.*)
kAdapt[infile_,rstr_,rend_,testE_,hi_,nstep_]:= Module[{kl,evs1r,evout,data},
data=ImportData[inpath<>infile<>".h5"];
evout=
Reap[
		Do[
		kl=buildkGrid[data,rx,testE,hi,nstep];
						Do[
						(*Print["Working on "<>ToString[kx]<>","<>ToString[rx]]*)
							Sow[{data["radius"][[rx]],kl[[kx]],SCalcScale[data,rx,testE,hi,kl[[kx]]][[1]][[1]],SCalcScale[data,rx,testE,hi,kl[[kx]]][[2]]}]; 
						,{kx,1,Length[kl]}
						] (*close do over ktargets*)
	,{rx,rstr,rend}
	] (*close do over r*)
][[2,1]];
Return[evout] (*Close reap over r*)
]; (*close module*)

End[]

EndPackage[]


