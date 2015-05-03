#include "farmhash.h"
#include "MurmurHash2.h"
#include <cstdio>
#include <cstring>
#include <iostream>

using namespace std;

int main(int argc, char** argv) {
	uint64_t res;
	char* str = "Retezeckzahashovani";
	
	for (size_t i = 0; i < 1; ++i)
	{
		cout << util::Hash64(str, strlen(str)); 
		//res = MurmurHash64A(str, strlen(str), 0); 
	}

	cout << res;
	return 0;
}
