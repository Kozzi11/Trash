/* Generated by Nim Compiler v0.10.2 */
/*   (c) 2014 Andreas Rumpf */
/* The generated code is subject to the original license. */
/* Compiled for: Linux, amd64, clang */
/* Command for C compiler:
   clang -c -w -O3  -I/usr/lib/nim -o /home/kozak/Devel/D/Trash/source/nimcache/strutils.o /home/kozak/Devel/D/Trash/source/nimcache/strutils.c */
#define NIM_INTBITS 64
#include "nimbase.h"
typedef struct NimStringDesc NimStringDesc;
typedef struct TGenericSeq TGenericSeq;
struct  TGenericSeq  {
NI len;
NI reserved;
};
struct  NimStringDesc  {
  TGenericSeq Sup;
NIM_CHAR data[SEQ_DECL_SIZE];
};
N_NIMCALL(NI, nsuFindChar)(NimStringDesc* s, NIM_CHAR sub, NI start);

N_NIMCALL(NI, nsuFindChar)(NimStringDesc* s, NIM_CHAR sub, NI start) {
	NI result;
	result = 0;
	{
		NI i_94908;
		NI HEX3Atmp_94910;
		NI res_94913;
		i_94908 = 0;
		HEX3Atmp_94910 = 0;
		HEX3Atmp_94910 = (NI64)(s->Sup.len - 1);
		res_94913 = start;
		{
			while (1) {
				if (!(res_94913 <= HEX3Atmp_94910)) goto LA3;
				i_94908 = res_94913;
				{
					if (!((NU8)(sub) == (NU8)(s->data[i_94908]))) goto LA6;
					result = i_94908;
					goto BeforeRet;
				}
				LA6: ;
				res_94913 += 1;
			} LA3: ;
		}
	}
	result = -1;
	goto BeforeRet;
	BeforeRet: ;
	return result;
}

N_NIMCALL(NIM_BOOL, contains_95245)(NimStringDesc* s, NIM_CHAR c) {
	NIM_BOOL result;
	NI LOC1;
	result = 0;
	LOC1 = 0;
	LOC1 = nsuFindChar(s, c, 0);
	result = (0 <= LOC1);
	goto BeforeRet;
	BeforeRet: ;
	return result;
}
NIM_EXTERNC N_NOINLINE(void, HEX00_strutilsInit)(void) {
}

NIM_EXTERNC N_NOINLINE(void, HEX00_strutilsDatInit)(void) {
}

