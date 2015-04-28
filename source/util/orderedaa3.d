module util.orderedaa3;

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
        Item* items = null;
        size_t size;
        size_t count;
        void addItem(VT value, KT key, ref Appender!(Item*[]) orderedItems)
        {
            if (count == size)
            {
                size += defaultBucketSize;
                items = cast(Item *)core.stdc.stdlib.realloc(items, size * Item.sizeof);
            }
            Item* item = items + count;
            item.data = value;
            item.key = key;
            ++count;
            orderedItems.put(item);
        }

        void addItem(VT value, KT key, size_t position, ref Appender!(Item*[]) orderedItems)
        {
            if (count == size)
            {
                size += defaultBucketSize;
                items = cast(Item *)core.stdc.stdlib.realloc(items, size * Item.sizeof);
            }
            auto src = items + position;
            core.stdc.string.memmove(src + 1 , src, (count - position) * Item.sizeof);
            Item* item = items + position;
            item.data = value;
            item.key = key;
            ++count;
            orderedItems.put(item);
        }
        
    }
    
    struct Item
    {
        VT data;
        KT key;
    }
    
    private size_t _itemsCount;
    
    alias toBuiltinAA this;
    
    bool canCleanup = true;
    
    List[] hashTable = void;

    auto orderedItems = appender!(Item*[])();
    
    @property length()
    {
        return _itemsCount;
    }
    
    @property VT[] values()
    {
        auto values = appender!(VT[])();
        values.reserve(_itemsCount);

        foreach(current; orderedItems.data)
        {
            values.put(current.data);
            
        }
        
        return values.data;
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
            list.items = cast(Item*) core.stdc.stdlib.malloc(defaultBucketSize * Item.sizeof);
            Item *item = list.items;
            item.key = key;
            item.data = args[1];
            item.next = null;
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
    
    VT[KT] toBuiltinAA()
    {
        VT[KT] baa;
        foreach(KT key, VT val; this)
        {
            baa[key] = val;
        }
        return baa;
    }
    
    VT* opBinaryRight(string op)(KT key) if (op == "in")
    {
        ptrdiff_t keyIndex = getKeyIndex(key);
        auto list = hashTable.ptr + keyIndex;
        auto current = list.items;
        
        for (size_t i; i < list.count; ++i)
        {
            if (current.key == key)
            {
                return &(current.data);
            }
            ++current;
        }
        return null;
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
            list.items = cast(Item*) core.stdc.stdlib.malloc(defaultBucketSize * Item.sizeof);
            Item *item = list.items;
            item.key = key;
            item.data = value;
            //item.next = null;
            list.size = defaultBucketSize;
            list.count = 1;
            orderedItems.put(item);
            ++_itemsCount;
            
        }
        else
        {
            ptrdiff_t keyIndex = getKeyIndex(key);
            auto list = hashTable.ptr + keyIndex;
            Item* current = list.items;
            size_t count = list.count;
            Item* end = current + count;

            if (current is null || key > (end - 1).key) {
                list.addItem(value, key, orderedItems);
                ++_itemsCount;
                return;
            }
            else if (key < current.key)
            {
                list.addItem(value, key, 0, orderedItems);
                ++_itemsCount;
            }
            else
            {
                current = list.items + (count >> 1);
                if (current.key > key)
                {
                    Item* start = list.items - 1;
                    while(current != start)
                    {
                        if (current.key == key)
                        {
                            current.data = value;
                            return;
                        }
                        else if (current.key < key)
                        {
                            ++_itemsCount;
                            list.addItem(value, key, current - list.items, orderedItems);
                            return;
                        }
                        --current;
                    }
                }
                else
                {
                    while(current != end)
                    {
                        if (current.key == key)
                        {
                            current.data = value;
                            return;
                        }
                        else if (current.key > key)
                        {
                            ++_itemsCount;
                            list.addItem(value, key, current - list.items, orderedItems);
                            return;
                        }
                        ++current;
                    }
                }
            }
        }
    }
    
    VT opIndex(KT key)
    {
        ptrdiff_t keyIndex = getKeyIndex(key);
        auto list = hashTable.ptr + keyIndex;

        size_t count = list.count;
        Item* current = list.items + (count >> 1);
        Item* end = current + count;

        
        if (current.key > key)
        {
            Item* start = list.items - 1;
            while(current != start)
            {
                if (current.key == key)
                {
                    return current.data;
                }
                else if (current.key < key)
                {
                    return VT.init;
                }
                --current;
            }
        }
        else
        {
            while(current != end)
            {
                if (current.key == key)
                {
                    return current.data;
                }
                else if (current.key > key)
                {
                    return VT.init;
                }
                ++current;
            }
        }
        
        return VT.init;
    }
    
    bool remove(KT key)
    {
        ptrdiff_t keyIndex = getKeyIndex(key);
        auto list = hashTable.ptr + keyIndex;
        
        return false;
    }
    
    int opApply(int delegate(KT key, ref VT value) dg)
    {
        int result = 0;

        
        foreach (current; orderedItems.data)
        {
            result = dg(current.key, current.data);
            if (result)
            {
                break;
            }
        }
        return result;
    }
    
    int opApply(int delegate(ref VT value) dg)
    {
        int result = 0;

        
        foreach (current; orderedItems.data)
        {
            result = dg(current.data);
            if (result)
            {
                break;
            }
            
        }
        return result;
    }
    
    
}

