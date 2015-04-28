module util.orderedaa4;

import util.murmurhash;
import std.traits;
import std.array : Appender, appender;
import std.conv;
import std.algorithm : swap;
import core.stdc.stdlib;
import core.exception;
import core.memory : GC;

enum DefaultHashTableSize = 1019;
enum defaultBucketSize = 5;

auto orderedAA(size_t hashTableSize = DefaultHashTableSize, T...)(T args)
{
    return OrderedAA!(T[1], T[0], hashTableSize)(args);
}

struct OrderedAA(VT, KT, size_t hashTableSize = DefaultHashTableSize)
{
    struct List
    {
        KT* keys = null;
        VT* values = null;
        size_t size;
        size_t count;
        void addItem(VT value, KT key)
        {
            if (count == size)
            {
                size += defaultBucketSize;
                keys = cast(KT*)core.stdc.stdlib.realloc(keys, size * KT.sizeof);
                values = cast(VT*)core.stdc.stdlib.realloc(values, size * VT.sizeof);
            }
            *(keys + count) = key;
            *(values + count) = value;
            ++count;
        }

        void addItem(VT value, KT key, size_t position)
        {
            if (count == size)
            {
                size += defaultBucketSize;
                keys = cast(KT*)core.stdc.stdlib.realloc(keys, size * KT.sizeof);
                values = cast(VT*)core.stdc.stdlib.realloc(values, size * VT.sizeof);
            }
            auto src = keys + position;
            core.stdc.string.memmove(src + 1 , src, (count - position) * KT.sizeof);
            src = values + position;
            core.stdc.string.memmove(src + 1 , src, (count - position) * VT.sizeof);
            *(keys + count) = key;
            *(values + count) = value;
            ++count;
        }
        
    }
    
    struct Item
    {
        VT data;
        KT key;
    }
    
    private size_t _itemsCount;
    
    //alias toBuiltinAA this;
    
    bool canCleanup = true;
    
    List[] hashTable = void;
    
    @property length()
    {
        return _itemsCount;
    }
    

    
    this(this)
    {
        canCleanup = false;
    }
    
    this(T...)(T args) if (args.length > 1)
    {
        KT key;
        
        auto p = core.stdc.stdlib.calloc(hashTableSize, List.sizeof);
        if (!p)
        {
            throw new OutOfMemoryError();
        }
        
        hashTable = (cast(List *)p)[0 .. hashTableSize];
        
        static if (is(T[0] == KT) && is(T[1] == VT))
        {
            ptrdiff_t i = getKeyIndex(args[0]);
            key = args[0];
            List* list = hashTable.ptr + i;
            list.keys = cast(KT*) core.stdc.stdlib.malloc(defaultBucketSize * KT.sizeof);
            list.values = cast(VT*) core.stdc.stdlib.malloc(defaultBucketSize * VT.sizeof);
            *(list.keys) = key;
            *(list.values) = args[1];
            list.size = defaultBucketSize;
            list.count = 1;
            ++_itemsCount;
        }
        
        foreach (index, arg; args[2 .. $])
        {
            if (index % 2 == 0)
            {
                static if (is(T[2+index] == KT))
                {
                    key = arg;
                }
            }
            else
            {
                static if (is(T[2+index] == VT))
                {
                    opIndexAssign(arg, key);
                }
            }
        }
    }
    
    ~this()
    {
        if (canCleanup)
        {
            core.stdc.stdlib.free(hashTable.ptr);
        }
    }
    
    sizediff_t getKeyIndex(T)(T key)
    {
        static if (isIntegral!T)
        {
            return key % hashTableSize;
        }
        else
        {
            return MurmurHash64(key) % hashTableSize;
        }
    }
    
    void opIndexAssign(VT value, KT key)
    {
        if (hashTable.length != hashTableSize)
        {

            auto p = core.stdc.stdlib.calloc(hashTableSize, List.sizeof);
            if (!p)
            {
                throw new OutOfMemoryError();
            }
            hashTable = (cast(List *)p)[0 .. hashTableSize];

            ptrdiff_t i = getKeyIndex(key);
            List* list = hashTable.ptr + i;

            list.keys = cast(KT*) core.stdc.stdlib.malloc(defaultBucketSize * KT.sizeof);
            list.values = cast(VT*) core.stdc.stdlib.malloc(defaultBucketSize * VT.sizeof);
            *(list.keys) = key;
            *(list.values) = value;
            list.size = defaultBucketSize;
            list.count = 1;
            ++_itemsCount;
            
        }
        else
        {
            ptrdiff_t keyIndex = getKeyIndex(key);
            auto list = hashTable.ptr + keyIndex;
            KT* current = list.keys;
            size_t count = list.count;
            KT* end = current + count;

            if (current is null || key > *(end - 1)) {
                list.addItem(value, key);
                ++_itemsCount;
                return;
            }
            else if (key < *current)
            {
                list.addItem(value, key, 0);
                ++_itemsCount;
            }
            else
            {
                current = list.keys + (count >> 1);
                if (*current > key)
                {
                    KT* start = list.keys - 1;
                    while(current != start)
                    {
                        if (*current == key)
                        {
                            *(list.values + (current - start)) = value;
                            return;
                        }
                        else if (*current < key)
                        {
                            ++_itemsCount;
                            list.addItem(value, key, current - list.keys);
                            return;
                        }
                        --current;
                    }
                }
                else
                {
                    while(current != end)
                    {
                        if (*current == key)
                        {
                            *(list.values + (current - list.keys)) = value;
                            return;
                        }
                        else if (*current > key)
                        {
                            ++_itemsCount;
                            list.addItem(value, key, current - list.keys);
                            return;
                        }
                        ++current;
                    }
                }
            }
        }
    }

    KT* findKey(KT key, KT* haystack, size_t length)
    {
        while (length >= 0)
        {
            size_t prevLength = length;
            length >>= 1;
            auto tmp = haystack + length;
            if (*tmp < key)
            {
                haystack = haystack + (prevLength - length);
            } else if (*tmp == key) return tmp;
        }
        return null;
    }
    
    VT opIndex(KT key)
    {
        ptrdiff_t keyIndex = getKeyIndex(key);
        auto list = hashTable.ptr + keyIndex;

        size_t count = list.count;
        KT* current = findKey(key, list.keys, count);
        if (current)
        {
            return *(list.values + (current - list.keys));
        }
        
        return VT.init;
    }
    
    bool remove(KT key)
    {
        ptrdiff_t keyIndex = getKeyIndex(key);
        auto list = hashTable.ptr + keyIndex;
        
        return false;
    }
    
}

