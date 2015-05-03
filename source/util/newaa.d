module util.newaa;

import util.murmurhash;
import std.traits;
import std.typecons;
import std.stdio : writeln;
import core.stdc.stdlib;
import core.exception;
import core.memory : GC;
import core.stdc.string;

enum DefaultHashTableSize = 32;
enum defaultBucketSize = 6;

auto newAA(size_t hashTableSize = DefaultHashTableSize, T...)(T args)
{
    return NewAA!(T[1], T[0], hashTableSize)(args);
}



void GCaddRangeNewAA(VT, KT)(VT* values, KT* keys, size_t size)
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

void GCremoveRangeNewAA(VT, KT)(VT* values, KT* keys)
{
    static if ((isArray!VT || isAggregateType!VT) && (isArray!KT || isAggregateType!KT))
    {
        GC.removeRange(keys);
    }
    else static if (isArray!VT || isAggregateType!VT)
    {
        GC.removeRange(values);
    }
    else static if (isArray!KT || isAggregateType!KT)
    {
        GC.removeRange(keys);
    }
}

struct NewAA(VT, KT, size_t startHashTableSize = DefaultHashTableSize)
{

    /*static struct HashKey
     {
     hash_t hash;
     KT key;

     bool opEquals(const HashKey s) const {
     if (hash!=s.hash) return false;
     return key==s.key;
     }
     }*/

    //static if (!isIntegral!KT)
    //{
    //    alias RKT = HashKey;
    //} else {
    alias RKT = KT;
    //}

    static struct Item
    {
        RKT key;
        VT value;
        RKT* keys = null;
        VT* values = null;
    }

    static struct List
    {
        Item item;
        int count = 0;
        int size = 0;
        size_t position;

        void addItem(VT value, RKT key)
        {
            if (size < count) {
                size += defaultBucketSize;
                auto oldKeys = item.keys;
                auto oldValues = item.values;
                item.keys = cast(RKT*)GC.realloc(item.keys, size * (RKT.sizeof + VT.sizeof));
                item.values = cast(VT*)(item.keys + size);
                if (count > 1) {
                    auto oldSize = size - defaultBucketSize;
                    memmove(item.values, cast(VT*)(item.keys + oldSize), (count-1) * VT.sizeof);
                }
            }
            *(item.keys + count - 1) = key;
            *(item.values + count - 1) = value;
            ++count;
        }

        void popFront()
        {
            ++position;
        }

        auto front()
        {
            return position == 0 ? tuple(item.value, item.key) : tuple(*(item.values + position - 1), *(item.keys + position - 1));
        }

        bool empty()
        {
            return count == position;
        }
    }

    size_t hashTableSize = startHashTableSize;
    
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

    void rehash()
    {
        auto oldTable = hashTable;
        auto oldTableSize = hashTableSize;
        hashTableSize = hashTableSize << 4;
        hashTable = cast(List *)GC.calloc(hashTableSize * List.sizeof);
        //GC.addRange(hashTable, hashTableSize * List.sizeof);
        foreach (listItem; oldTable[0 .. oldTableSize])
        {
            foreach (value, key; listItem)
            {
                addRehash(value, key);
            }
        }
        //GC.removeRange(oldTable);
        GC.free(oldTable);
    }

    
    this(T...)(T args) if (args.length > 1)
    {
        KT key;
        
        auto p = calloc(hashTableSize, List.sizeof);
        if (!p)
        {
            throw new OutOfMemoryError();
        }
        
        hashTable = (cast(List *)p);
        
        static if (is(T[0] == KT) && is(T[1] == VT))
        {
            VT* values = void;
            ptrdiff_t i = getKeyIndex(args[0]);
            key = args[0];
            List* list = hashTable + i;
            auto keys = cast(KT*)malloc(defaultBucketSize * (KT.sizeof + VT.sizeof));
            list.keys = keys;
            values = cast(VT*)(list.keys + defaultBucketSize);
            static if (isArray!VT || isAggregateType!VT || isArray!KT || isAggregateType!KT)
            {
                GCaddRangeNewAA!(values, keys, VT, KT)(defaultBucketSize);
            }
            *(list.keys) = key;
            *(values) = args[1];
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
        /*if (canCleanup)
         {
         foreach (list; hashTable[0 .. hashTableSize])
         {
         core.stdc.stdlib.free(list.keys);
         }
         core.stdc.stdlib.free(hashTable);
         }*/
    }

    hash_t getKeyHash(T)(T key)
    {
        static if (isIntegral!T)
        {
            import util.fasthash;
            return key;//HashLenIntegral(key);
        }
        else
        {
            import util.fasthash;
            return FarmHash64(key);
            //return MurmurHash64(key);
        }
    }
    
    size_t getKeyIndex(T)(T key)
    {       
        return getKeyHash(key) & (hashTableSize-1);
    }

    void opIndexAssign(VT value, KT key)
    {
        if (hashTable is null)
        {
            auto p = GC.calloc(hashTableSize * List.sizeof);
            if (!p)
            {
                throw new OutOfMemoryError();
            }

            hashTable = (cast(List *)p);
        }

        hash_t hash = getKeyHash(key);
        size_t keyIndex = hash  & (hashTableSize-1);
        auto list = hashTable + keyIndex;

        /*static if (is(RKT : HashKey))
         {
         RKT newKey = RKT(hash, key);
         if (list.count == 0)
         {
         list.item.key = newKey;
         list.item.value = value;
         ++list.count;
         ++_itemsCount;
         }
         else if (list.item.key == newKey) 
         {
         list.item.value = value;
         }
         else 
         {
         RKT* haystack = list.item.keys;
         int offset = 1;
         
         while (offset < list.count)
         {
         if (*(haystack) == newKey)
         {
         *(list.item.values + offset - 1) = value;
         return;
         }
         ++haystack;
         ++offset;
         }
         list.addItem(value, newKey);
         ++_itemsCount;
         if (_itemsCount > hashTableSize * (defaultBucketSize >> 1))
         {
         rehash;
         }
         }
         } else {*/
        
        //     
        if (list.count == 0)
        {
            list.item.key = key;
            list.item.value = value;
            ++list.count;
            ++_itemsCount;
            return;
        }
        if (list.item.key == key) 
        {
            list.item.value = value;
        }
        else 
        {
            KT* haystack = list.item.keys;
            int offset = 1;
            
            while (offset < list.count)
            {
                if (*(haystack) == key)
                {
                    *(list.item.values + offset - 1) = value;
                    return;
                }
                ++haystack;
                ++offset;
            }
            list.addItem(value, key);
            ++_itemsCount;
            if (_itemsCount > hashTableSize * (defaultBucketSize >> 1))
            {
                rehash();
            }
        }
        //}
    }

    void addRehash(VT value, RKT key)
    {
        //static if (is(RKT : HashKey)) {
        //     size_t keyIndex = key.hash & (hashTableSize-1);
        // } else {
        size_t keyIndex = getKeyIndex(key);
        // }

        auto list = hashTable + keyIndex;
        if (list.count == 0)
        {
            list.item.key = key;
            list.item.value = value;
            ++list.count;
        }
        else 
        {
            list.addItem(value, key);
        }
    }

    VT opIndex(KT key)
    {
        hash_t hash = getKeyHash(key);
        size_t keyIndex = hash  & (hashTableSize-1);
        auto list = hashTable + keyIndex;
        
        /*static if (is(RKT : HashKey))
         {
         RKT newKey = RKT(hash, key);
         if (list.item.key == newKey)
         {
         return list.item.value;
         }
         else
         {
         auto haystack = list.item.keys;
         int offset = 1;
         
         while (offset < list.count)
         {
         if (*(haystack) == newKey)
         {
         return *(list.item.values + offset - 1);
         }
         ++haystack;
         ++offset;
         }
         }
         } else {*/
        if (list.item.key == key)
        {
            return list.item.value;
        }
        else
        {
            auto haystack = list.item.keys;
            int offset = 1;

            while (offset < list.count)
            {
                if (*(haystack) == key)
                {
                    return *(list.item.values + offset - 1);
                }
                ++haystack;
                ++offset;
            }
        }
        //}
        return VT.init;
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

