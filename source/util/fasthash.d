module util.fasthash;
import std.algorithm : swap;
import core.stdc.string;
import std.typecons;
import std.stdio;

// Some primes between 2^63 and 2^64 for various uses.
enum k0 = 0xc3a5c85c97cb3127;
enum k1 = 0xb492b66fbe98f273;
enum k2 = 0x9ae16a3b2f90404f;

// Magic numbers for 32-bit hashing.  Copied from Murmur3.
enum uint c1 = 0xcc9e2d51;
enum uint c2 = 0x1b873593;

ulong mix(T)(T h) pure nothrow @nogc
{
    h ^= (h) >> 23;
    h *= 0x2127599bf4325c37;
    h ^= (h) >> 47; 
    return h;
}

ulong fasthash64(T:K[], K)(const T buf, immutable ulong seed = 0) pure nothrow @nogc
{
    const ulong m = 0x880355f21e6d1965;
    ulong *pos = cast(ulong *)buf;
    size_t len = buf.length;
    const ulong *end = pos + (len / 8);
    ubyte *pos2;
    ulong h = seed ^ (len * m);
    ulong v;
    
    while (pos != end) {
        v  = *pos++;
        h ^= mix(v);
        h *= m;
    }
    
    pos2 = cast(ubyte*)pos;
    v = 0;
    
    switch (len & 7) {
        case 7: v ^= cast(ulong)pos2[6] << 48; goto case;
        case 6: v ^= cast(ulong)pos2[5] << 40; goto case;
        case 5: v ^= cast(ulong)pos2[4] << 32; goto case;
        case 4: v ^= cast(ulong)pos2[3] << 24; goto case;
        case 3: v ^= cast(ulong)pos2[2] << 16; goto case;
        case 2: v ^= cast(ulong)pos2[1] << 8; goto case;
        case 1: v ^= cast(ulong)pos2[0]; goto default;
        default:
            h ^= mix(v);
            h *= m;
    }
    
    return mix(h);
}

ulong FarmHash64(T:K[], K)(const T buf) pure nothrow @nogc
{
    const(char)* s = cast(const(char*))buf.ptr;
    immutable len = buf.length;

    const ulong seed = 81;
    if (len <= 32) {
        if (len <= 16) {
            return HashLen0to16(s, len);
        } else {
            return HashLen17to32(s, len);
        }
    } else if (len <= 64) {
        return HashLen33to64(s, len);
    }
    
    // For strings over 64 bytes we loop.  Internal state consists of
    // 56 bytes: v, w, x, y, and z.
    ulong x = seed;
    ulong y = seed * k1 + 113;
    ulong z = ShiftMix(y * k2 + 113) * k2;
    auto v = tuple!(ulong, ulong)(0, 0);
    auto w = tuple!(ulong, ulong)(0, 0);
    x = x * k2 + Fetch(s);
    
    // Set end so that after the loop we have 1 to 64 bytes left to process.
    const char* end = s + ((len - 1) / 64) * 64;
    const char* last64 = end + ((len - 1) & 63) - 63;
    assert(s + len - 64 == last64);
    do {
        x = Rotate(x + y + v[0] + Fetch(s + 8), 37) * k1;
        y = Rotate(y + v[1] + Fetch(s + 48), 42) * k1;
        x ^= w[1];
        y += v[0] + Fetch(s + 40);
        z = Rotate(z + w[0], 33) * k1;
        v = WeakHashLen32WithSeeds(s, v[1] * k1, x + w[0]);
        w = WeakHashLen32WithSeeds(s + 32, z + w[1], y + Fetch(s + 16));
        swap(z, x);
        s += 64;
    } while (s != end);
    ulong mul = k1 + ((z & 0xff) << 1);
    // Make s point to the last 64 bytes of input.
    s = last64;
    w[0] += ((len - 1) & 63);
    v[0] += w[0];
    w[0] += v[0];
    x = Rotate(x + y + v[0] + Fetch(s + 8), 37) * mul;
    y = Rotate(y + v[1] + Fetch(s + 48), 42) * mul;
    x ^= w[1] * 9;
    y += v[0] * 9 + Fetch(s + 40);
    z = Rotate(z + w[0], 33) * mul;
    v = WeakHashLen32WithSeeds(s, v[1] * mul, x + w[0]);
    w = WeakHashLen32WithSeeds(s + 32, z + w[1], y + Fetch(s + 16));
    swap(z, x);
    return HashLen16(HashLen16(v[0], w[0], mul) + ShiftMix(y) * k0 + z,
        HashLen16(v[1], w[1], mul) + x,
        mul);
}

alias Fetch = Fetch64;
alias Rotate = Rotate64;


// Return a 16-byte hash for 48 bytes.  Quick and dirty.
// Callers do best to use "random-looking" values for a and b.
auto WeakHashLen32WithSeeds(ulong w, ulong x, ulong y, ulong z, ulong a, ulong b) pure nothrow @nogc
{
    a += w;
    b = Rotate(b + a + z, 21);
    ulong c = a;
    a += x;
    a += y;
    b += Rotate(a, 44);
    return tuple(a + z, b + c);
}

// Return a 16-byte hash for s[0] ... s[31], a, and b.  Quick and dirty.
auto WeakHashLen32WithSeeds(const char* s, ulong a, ulong b) pure nothrow @nogc
{
    return WeakHashLen32WithSeeds(Fetch(s),
        Fetch(s + 8),
        Fetch(s + 16),
        Fetch(s + 24),
        a,
        b);
}

ulong ShiftMix(ulong val) pure nothrow @nogc
{
    return val ^ (val >> 47);
}

/*ulong HashLen16(ulong u, ulong v) {
 return Hash128to64(Uint128(u, v));
 }*/

//ulong Hash128to64(uint128_t x) {
//    // Murmur-inspired hashing.
//    enum ulong kMul = 0x9ddfea08eb382d69ULL;
//    ulong a = (Uint128Low64(x) ^ Uint128High64(x)) * kMul;
//    a ^= (a >> 47);
//    ulong b = (Uint128High64(x) ^ a) * kMul;
//    b ^= (b >> 47);
//    b *= kMul;
//    return b;
//}

ulong HashLen16(ulong u, ulong v, ulong mul) pure nothrow @nogc
{
    // Murmur-inspired hashing.
    ulong a = (u ^ v) * mul;   
    a ^= (a >> 47);
    ulong b = (v ^ a) * mul;
    b ^= (b >> 47);
    b *= mul;
    return b;
}

ulong HashLen0to16(const char *s, size_t len) pure nothrow @nogc
{
    if (len >= 8) {
        ulong mul = k2 + len * 2;
        ulong a = Fetch(s) + k2;
        ulong b = Fetch(s + len - 8);
        ulong c = Rotate(b, 37) * mul + a;
        ulong d = (Rotate(a, 25) + b) * mul;
        return HashLen16(c, d, mul);
    }
    if (len >= 4) {
        ulong mul = k2 + len * 2;
        ulong a = Fetch32(s);
        return HashLen16(len + (a << 3), Fetch32(s + len - 4), mul);
    }
    if (len > 0) {
        ubyte a = s[0];
        ubyte b = s[len >> 1];
        ubyte c = s[len - 1];
        uint y = (cast(uint)a) + (cast(uint)(b) << 8);
        uint z = cast(uint)len + (cast(uint)(c) << 2);
        return ShiftMix(y * k2 ^ z * k0) * k2;
    }
    return k2;
}

ulong HashLen17to32(const char *s, size_t len) pure nothrow @nogc
{
    ulong mul = k2 + len * 2;
    ulong a = Fetch(s) * k1;
    ulong b = Fetch(s + 8);
    ulong c = Fetch(s + len - 8) * mul;
    ulong d = Fetch(s + len - 16) * k2;
    return HashLen16(Rotate(a + b, 43) + Rotate(c, 30) + d,
        a + Rotate(b + k2, 18) + c, mul);
}

// Return an 8-byte hash for 33 to 64 bytes.
ulong HashLen33to64(const char *s, size_t len) pure nothrow @nogc
{
    ulong mul = k2 + len * 2;
    ulong a = Fetch(s) * k2;
    ulong b = Fetch(s + 8);
    ulong c = Fetch(s + len - 8) * mul;
    ulong d = Fetch(s + len - 16) * k2;
    ulong y = Rotate(a + b, 43) + Rotate(c, 30) + d;
    ulong z = HashLen16(y, a + Rotate(b + k2, 18) + c, mul);
    ulong e = Fetch(s + 16) * mul;
    ulong f = Fetch(s + 24);
    ulong g = (y + Fetch(s + len - 32)) * mul;
    ulong h = (z + Fetch(s + len - 24)) * mul;
    return HashLen16(Rotate(e + f, 43) + Rotate(g, 30) + h,
        e + Rotate(f + a, 18) + g, mul);
}

uint Rotate32(uint val, int shift) pure nothrow @nogc
{
    return BasicRotate32(val, shift);
}
ulong Rotate64(ulong val, int shift) pure nothrow @nogc
{
    return BasicRotate64(val, shift);
}

ulong Fetch64(const char *p) pure nothrow @nogc
{
    ulong result = *cast(ulong *)p;
    return (result);
}

uint Fetch32(const char *p) pure nothrow @nogc
{
    uint result = *cast(uint *)p;
    return (result);
}

// FARMHASH PORTABILITY LAYER: bitwise rot

uint BasicRotate32(uint val, int shift) pure nothrow @nogc
{
    // Avoid shifting by 32: doing so yields an undefined result.
    return shift == 0 ? val : ((val >> shift) | (val << (32 - shift)));
}

ulong BasicRotate64(ulong val, int shift) pure nothrow @nogc
{
    // Avoid shifting by 64: doing so yields an undefined result.
    return shift == 0 ? val : ((val >> shift) | (val << (64 - shift)));
}