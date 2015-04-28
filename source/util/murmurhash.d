module util.murmurhash;

import std.stdio;

uint rotl32(uint x, byte r)
{
    return (x << r) | (x >> (32 - r));
}

ulong rotl64(ulong x, byte r)
{
    return (x << r) | (x >> (64 - r));
}

//-----------------------------------------------------------------------------
// Finalization mix - force all bits of a hash block to avalanche

uint fmix(uint h)
{
    h ^= h >> 16;
    h *= 0x85ebca6b;
    h ^= h >> 13;
    h *= 0xc2b2ae35;
    h ^= h >> 16;
    
    return h;
}

//----------

ulong fmix(ulong k)
{
    k ^= k >> 33;
    k *= 0xff51afd7ed558ccdUL;
    k ^= k >> 33;
    k *= 0xc4ceb9fe1a85ec53UL;
    k ^= k >> 33;
    
    return k;
}

//-----------------------------------------------------------------------------

uint MurmurHash32 (immutable void[] key, int len, uint seed)
{
    auto data = cast(immutable ubyte[])key;
    immutable int nblocks = len >> 2;
    
    uint h1 = seed;
    
    uint c1 = 0xcc9e2d51;
    uint c2 = 0x1b873593;
    
    //----------
    // body
    
    auto blocks = (cast(immutable uint*)(data.ptr))[0 .. nblocks];
    
    foreach(block; blocks)
    {
        uint k1 = block;
        
        k1 *= c1;
        k1 = rotl32(k1,15);
        k1 *= c2;
        
        h1 ^= k1;
        h1 = rotl32(h1,13); 
        h1 = h1*5+0xe6546b64;
    }
    
    //----------
    // tail
    
    auto tail = data[nblocks*4 .. $];
    
    uint k1 = 0;
    
    switch(len & 3)
    {
        case 3: k1 ^= tail[2] << 16;
        case 2: k1 ^= tail[1] << 8;
        case 1: k1 ^= tail[0];
        default:
            k1 *= c1; k1 = rotl32(k1,15); k1 *= c2; h1 ^= k1;
    };
    
    //----------
    // finalization
    
    h1 ^= len;
    
    h1 = fmix(h1);
    return h1;
} 

//-----------------------------------------------------------------------------
version(X86)
{
    uint[] MurmurHash128 (immutable void[] key, const int len, uint seed)
    {
        auto data = cast(immutable ubyte[])key;
        immutable int nblocks = len >> 4;
        
        uint h1 = seed;
        uint h2 = seed;
        uint h3 = seed;
        uint h4 = seed;
        
        uint c1 = 0x239b961b; 
        uint c2 = 0xab0e9789;
        uint c3 = 0x38b34ae5; 
        uint c4 = 0xa1e38b93;
        
        //----------
        // body
        
        auto blocks = cast(immutable uint[])(data)[0 .. nblocks * 4];
        
        for(int i = 0; i < nblocks; ++i)
        {
            uint k1 = nblocks[i++];
            uint k2 = nblocks[i++];
            uint k3 = nblocks[i++];
            uint k4 = nblocks[i];
            
            k1 *= c1; k1  = rotl32(k1,15); k1 *= c2; h1 ^= k1;
            
            h1 = rotl32(h1,19); h1 += h2; h1 = h1*5+0x561ccd1b;
            
            k2 *= c2; k2  = rotl32(k2,16); k2 *= c3; h2 ^= k2;
            
            h2 = rotl32(h2,17); h2 += h3; h2 = h2*5+0x0bcaa747;
            
            k3 *= c3; k3  = rotl32(k3,17); k3 *= c4; h3 ^= k3;
            
            h3 = rotl32(h3,15); h3 += h4; h3 = h3*5+0x96cd1c35;
            
            k4 *= c4; k4  = rotl32(k4,18); k4 *= c1; h4 ^= k4;
            
            h4 = rotl32(h4,13); h4 += h1; h4 = h4*5+0x32ac3b17;
        }
        
        //----------
        // tail
        
        auto tail = data[nblocks*16 .. $];
        
        uint k1 = 0;
        uint k2 = 0;
        uint k3 = 0;
        uint k4 = 0;
        
        switch(len & 15)
        {
            case 15: k4 ^= tail[14] << 16;
            case 14: k4 ^= tail[13] << 8;
            case 13: k4 ^= tail[12] << 0;
                k4 *= c4; k4  = rotl32(k4,18); k4 *= c1; h4 ^= k4;
                
            case 12: k3 ^= tail[11] << 24;
            case 11: k3 ^= tail[10] << 16;
            case 10: k3 ^= tail[ 9] << 8;
            case  9: k3 ^= tail[ 8] << 0;
                k3 *= c3; k3  = rotl32(k3,17); k3 *= c4; h3 ^= k3;
                
            case  8: k2 ^= tail[ 7] << 24;
            case  7: k2 ^= tail[ 6] << 16;
            case  6: k2 ^= tail[ 5] << 8;
            case  5: k2 ^= tail[ 4] << 0;
                k2 *= c2; k2  = rotl32(k2,16); k2 *= c3; h2 ^= k2;
                
            case  4: k1 ^= tail[ 3] << 24;
            case  3: k1 ^= tail[ 2] << 16;
            case  2: k1 ^= tail[ 1] << 8;
            case  1: k1 ^= tail[ 0] << 0;
            default:
                k1 *= c1; k1  = rotl32(k1,15); k1 *= c2; h1 ^= k1;
        };
        
        //----------
        // finalization
        
        h1 ^= len; h2 ^= len; h3 ^= len; h4 ^= len;
        
        h1 += h2; h1 += h3; h1 += h4;
        h2 += h1; h3 += h1; h4 += h1;
        
        h1 = fmix(h1);
        h2 = fmix(h2);
        h3 = fmix(h3);
        h4 = fmix(h4);
        
        h1 += h2; h1 += h3; h1 += h4;
        h2 += h1; h3 += h1; h4 += h1;
        
        return [h1, h2, h3, h4];
    }
}
//-----------------------------------------------------------------------------

version(X86_64)
{
    ulong[] MurmurHash128 (immutable void[] key, const int len, immutable uint seed)
    {
        auto data = cast(immutable ubyte[])key;
        immutable int nblocks = len >> 4;
        
        ulong h1 = seed;
        ulong h2 = seed;
        
        ulong c1 = 0x87c37b91114253d5UL;
        ulong c2 = 0x4cf5ad432745937fUL;
        
        //----------
        // body
        
        auto blocks = cast(immutable ulong[])(data);
        
        for(int i = 0; i < nblocks; i++)
        {
            ulong k1 = blocks[i*2+0];
            ulong k2 = blocks[i*2+1];
            
            k1 *= c1; k1  = rotl64(k1,31); k1 *= c2; h1 ^= k1;
            
            h1 = rotl64(h1,27); h1 += h2; h1 = h1*5+0x52dce729;
            
            k2 *= c2; k2  = rotl64(k2,33); k2 *= c1; h2 ^= k2;
            
            h2 = rotl64(h2,31); h2 += h1; h2 = h2*5+0x38495ab5;
        }
        
        //----------
        // tail
        
        auto tail = data[nblocks*16 .. $];
        
        ulong k1 = 0;
        ulong k2 = 0;
        
        switch(len & 15)
        {
            case 15: k2 ^= cast(ulong)(tail[14]) << 48;
            case 14: k2 ^= cast(ulong)(tail[13]) << 40;
            case 13: k2 ^= cast(ulong)(tail[12]) << 32;
            case 12: k2 ^= cast(ulong)(tail[11]) << 24;
            case 11: k2 ^= cast(ulong)(tail[10]) << 16;
            case 10: k2 ^= cast(ulong)(tail[ 9]) << 8;
            case  9: k2 ^= cast(ulong)(tail[ 8]) << 0;
                k2 *= c2; k2  = rotl64(k2,33); k2 *= c1; h2 ^= k2;
                
            case  8: k1 ^= cast(ulong)(tail[ 7]) << 56;
            case  7: k1 ^= cast(ulong)(tail[ 6]) << 48;
            case  6: k1 ^= cast(ulong)(tail[ 5]) << 40;
            case  5: k1 ^= cast(ulong)(tail[ 4]) << 32;
            case  4: k1 ^= cast(ulong)(tail[ 3]) << 24;
            case  3: k1 ^= cast(ulong)(tail[ 2]) << 16;
            case  2: k1 ^= cast(ulong)(tail[ 1]) << 8;
            case  1: k1 ^= cast(ulong)(tail[ 0]) << 0;
            default:
                k1 *= c1; k1  = rotl64(k1,31); k1 *= c2; h1 ^= k1;
        };
        
        //----------
        // finalization
        
        h1 ^= len; h2 ^= len;
        
        h1 += h2;
        h2 += h1;
        
        h1 = fmix(h1);
        h2 = fmix(h2);
        
        h1 += h2;
        h2 += h1;
        
        return [h1, h2];
    }
}

version(X86_64)
{
    // 64-bit hash for 64-bit platforms
    
    ulong MurmurHash64(T: K[], K)(T key, immutable uint seed = 0)
    {
        immutable ulong m = 0xc6a4a7935bd1e995;
        immutable int r = 47;
        int len = (cast(int)key.length);
        int nblocks = len >> 3;
        
        ulong h = seed ^ (len * m);
        
        auto data = (cast(immutable(ulong)*)key.ptr);
        
        while(nblocks--)
        {
            ulong k = *data++;
            
            k *= m;
            k ^= k >> r;
            k *= m;
            
            h ^= k;
            h *= m;
        }
        
        auto tail = (cast(immutable ubyte*)key.ptr);
        
        switch(len & 7)
        {
            case 7: h ^= cast(ulong)(tail[6]) << 48;
            case 6: h ^= cast(ulong)(tail[5]) << 40;
            case 5: h ^= cast(ulong)(tail[4]) << 32;
            case 4: h ^= cast(ulong)(tail[3]) << 24;
            case 3: h ^= cast(ulong)(tail[2]) << 16;
            case 2: h ^= cast(ulong)(tail[1]) << 8;
            case 1: h ^= cast(ulong)(tail[0]);
            default:
                h *= m;
        };
        
        h ^= h >> r;
        h *= m;
        h ^= h >> r;
        
        return h;
    }
    
}

version(X86)
{
    // 64-bit hash for 32-bit platforms
    
    ulong MurmurHash64 (immutable void[] key, int len, immutable uint seed)
    {
        immutable uint m = 0x5bd1e995;
        immutable int r = 24;
        
        uint h1 = seed ^ len;
        uint h2 = 0;
        
        auto data = cast(immutable uint[])key;
        
        while(len >= 8)
        {
            uint k1 = data[0];
            data = data[1 .. $];
            k1 *= m; k1 ^= k1 >> r; k1 *= m;
            h1 *= m; h1 ^= k1;
            len -= 4;
            
            uint k2 = data[0];
            data = data[1 .. $];
            k2 *= m; k2 ^= k2 >> r; k2 *= m;
            h2 *= m; h2 ^= k2;
            len -= 4;
        }
        
        if(len >= 4)
        {
            uint k1 = data[0];
            data = data[1 .. $];
            k1 *= m; k1 ^= k1 >> r; k1 *= m;
            h1 *= m; h1 ^= k1;
            len -= 4;
        }
        
        switch(len)
        {
            case 3: h2 ^= (cast(char[])data)[2] << 16;
            case 2: h2 ^= (cast(char[])data)[1] << 8;
            case 1: h2 ^= (cast(char[])data)[0];
            default:
                h2 *= m;
        };
        
        h1 ^= h2 >> 18; h1 *= m;
        h2 ^= h1 >> 22; h2 *= m;
        h1 ^= h2 >> 17; h1 *= m;
        
        
        ulong h = h1;
        
        h = (h << 32) | h2;
        
        return h;
    }
}

