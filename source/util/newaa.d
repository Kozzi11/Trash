module util.newaa;

import util.murmurhash;
import std.traits;
import std.stdio : writeln;
import core.stdc.stdlib;
import core.exception;
import core.memory : GC;

enum DefaultHashTableSize = 1019;
enum defaultBucketSize = 5;

auto newAA(size_t hashTableSize = DefaultHashTableSize, T...)(T args)
{
    return NewAA!(T[1], T[0], hashTableSize)(args);
}

void GCaddRangeNewAA(alias values, alias keys, VT, KT)(size_t size)
{
    static if ((isArray!VT || isAggregateType!VT) && (isArray!KT || isAggregateType!KT))
    {
        GC.addRange(keys, size * (KT.sizeof + VT.sizeof));
    }
    else static if (isArray!VT || isAggregateType!VT)
    {
        GC.addRange(values, size * VT.sizeof);
    }
    else static if (isArray!KT || isAggregateType!KT)
    {
        GC.addRange(keys, size * KT.sizeof);
    }
}

struct NewAA(VT, KT, size_t hashTableSize = DefaultHashTableSize)
{
    struct List
    {
        KT* lastKey = null;
        KT* keys = null;

        size_t size;
        size_t count;
        void addItem(VT value, KT key)
        {
            VT* values = void;
            if (count == size)
            {
                size += defaultBucketSize;
                keys = cast(KT*)core.stdc.stdlib.realloc(keys, size * (KT.sizeof + VT.sizeof));
                values = cast(VT*)(keys + size);
                core.stdc.string.memmove(values, keys + count, count * VT.sizeof);

                static if (isArray!VT || isAggregateType!VT || isArray!KT || isAggregateType!KT)
                {
                    GCaddRangeNewAA!(values, keys, VT, KT)(size);
                }

            }
            else
            {
                values = cast(VT*)(keys + size);
            }
            lastKey = (keys + count);
            *lastKey = key;
            *(values + count) = value;
            ++count;
        }
        
    }
    
    private size_t _itemsCount;
    
    //alias toBuiltinAA this;
    
    bool canCleanup = true;
    
    List* hashTable = null;
    
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
        
        hashTable = (cast(List *)p);
        
        static if (is(T[0] == KT) && is(T[1] == VT))
        {
            ptrdiff_t i = getKeyIndex(args[0]);
            key = args[0];
            List* list = hashTable.ptr + i;
            list.keys = cast(KT*)core.stdc.stdlib.malloc(defaultBucketSize * (KT.sizeof + VT.sizeof));
            list.values = cast(VT*)(list.keys + defaultBucketSize);
            static if (isArray!VT || isAggregateType!VT || isArray!KT || isAggregateType!KT)
            {
                GCaddRangeNewAA!(list.values, list.keys, VT, KT)(defaultBucketSize);
            }
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
            foreach (list; hashTable[0 .. hashTableSize])
            {
                core.stdc.stdlib.free(list.keys);
            }
            core.stdc.stdlib.free(hashTable);
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

    VT* opBinaryRight(string op)(KT key) if (op == "in")
    {
        ptrdiff_t keyIndex = getKeyIndex(key);
        auto list = hashTable + keyIndex;

        return findKey(key, list);

    }

    void opIndexAssign(VT value, KT key)
    {
        if (hashTable is null)
        {
            auto p = core.stdc.stdlib.calloc(hashTableSize, List.sizeof);
            if (!p)
            {
                throw new OutOfMemoryError();
            }
            
            hashTable = (cast(List *)p);
        }
        ptrdiff_t keyIndex = getKeyIndex(key);
        auto list = hashTable + keyIndex;
        KT* current = list.keys;
        KT* end = list.lastKey;
        VT* values = cast(VT*)(current + list.size);

        if (current is null)
        {
            list.addItem(value, key);
            ++_itemsCount;
            return;
        }
        else
        {
            do
            {
                if (*current == key)
                {
                    *(values + (current - list.keys)) = value;
                    return;
                }
                else if (*end == key)
                {
                    *(values + (end - list.keys)) = value;
                    return;
                }
                else
                {
                    ++current;
                    --end;
                }
            }
            while (end != current);
            list.addItem(value, key);
            ++_itemsCount;
        }
        
    }

    KT* findKey(KT key, List* list)
    {
        KT* haystack = list.keys;
        KT* end = list.lastKey + 1;
        while (haystack != end )
        {
            if (*haystack == key)
            {
                return haystack;
            }
            ++haystack;
        }

        return null;
    }
    
    VT opIndex(KT key)
    {
        ptrdiff_t keyIndex = getKeyIndex(key);
        auto list = hashTable + keyIndex;
        auto result = findKey(key, list);

        return result is null ? VT.init : *(cast(VT*)(list.keys + list.size) + (result - list.keys));
    }

    /**
     * not implemented yet
     */
    bool remove(KT key)
    {
        ptrdiff_t keyIndex = getKeyIndex(key);
        auto list = hashTable + keyIndex;
        
        return false;
    }
    
}

