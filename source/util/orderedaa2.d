module util.orderedaa2;

import util.murmurhash;
import std.traits;
import std.array : Appender, appender;
import std.conv;
import core.stdc.stdlib;
import core.exception;
import core.memory : GC;

enum DefaultHashTableSize = 1019;

auto orderedAA(size_t hashTableSize = DefaultHashTableSize, T...)(T args)
{
    return OrderedAA!(T[1], T[0], hashTableSize)(args);
}

struct OrderedAA(VT, KT, size_t hashTableSize = DefaultHashTableSize)
{
    struct List
    {
        Item* head = null, tail = null;
    }
    
    struct Item
    {
        VT data;
        KT key;
        
        static void[] heap;
        enum preAllocatedCount = 6;
        
        Item* prev = null, next = null, leftItem = null, rightItem = null;
        
        this(VT data, KT key, Item* prev)
        {
            this.data = data;
            this.key = key;
            this.prev = prev;
        }
        
        new(size_t size)
        {
            void* p;
            if (heap.length < size)
            {
                p = core.stdc.stdlib.calloc(preAllocatedCount, size);
                
                if (!p)
                {
                    throw new OutOfMemoryError();
                }
                heap = p[size .. preAllocatedCount * size];
            }
            else
            {
                p = heap.ptr;
                heap = heap[size .. $];
            }
            
            static if ((isArray!VT || isAggregateType!VT) && (isArray!KT || isAggregateType!KT))
            {
                GC.addRange(p, KT.sizeof + VT.sizeof);
            }
            else static if (isArray!VT || isAggregateType!VT)
            {
                GC.addRange(p, KT.sizeof + VT.sizeof);
            }
            else static if (isArray!KT || isAggregateType!KT)
            {
                GC.addRange(p + VT.sizeof, KT.sizeof);
            }
            
            return p;
        }
        
        delete(void* p)
        {
            if (p)
            {
                core.stdc.stdlib.free(p);
                static if ((isArray!VT || isAggregateType!VT || isArray!KT || isAggregateType!KT))
                {
                    GC.removeRange(p);
                }
            }
        }
    }
    
    private size_t _itemsCount;
    
    alias toBuiltinAA this;
    
    bool canCleanup = true;
    
    List[] hashTable = void;
    
    private Item* first = null;
    
    private Item* last = null;
    
    @property length()
    {
        return _itemsCount;
    }
    
    @property VT[] values()
    {
        auto values = appender!(VT[])();
        values.reserve(_itemsCount);
        
        Item * current = first;
        while(current)
        {
            values.put(current.data);
            current = current.next;
            
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
            Item *item = new Item(args[1], key, null);
            (hashTable.ptr + i).head = item;
            (hashTable.ptr + i).tail = item;
            last = item;
            first = item;
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
            Item * current = first;
            Item * remove = void;
            while(current)
            {
                remove = current;
                current = current.next; 
                destroy(remove);
            }
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
        auto current = list.head;
        
        while (current && key >= current.key)
        {
            if (current.key == key)
            {
                return &(current.data);
            }
            current = current.rightItem;
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
        if (first is null)
        {
            if (hashTable.length != hashTableSize)
            {
                auto p = core.stdc.stdlib.calloc(hashTableSize, List.sizeof);
                if (!p)
                {
                    throw new OutOfMemoryError();
                }
                hashTable = (cast(List *)p)[0 .. hashTableSize];
            }
            ptrdiff_t keyIndex = getKeyIndex(key);
            auto list = hashTable.ptr + keyIndex;
            Item * current = void;
            first = last = list.head = list.tail = new Item(value, key, last);
            ++_itemsCount;
            
        }
        else
        {
            ptrdiff_t keyIndex = getKeyIndex(key);
            
            auto list = hashTable.ptr + keyIndex;
            Item * current = void;
            
            if (list.tail != list.head)
            {
                if (key > list.tail.key)
                {
                    auto newItem = new Item(value, key, last);
                    newItem.leftItem = list.tail;
                    list.tail = last = last.next = list.tail.rightItem = newItem;
                    ++_itemsCount;
                }
                else if (key < list.head.key)
                {
                    current = new Item(value, key, last);       
                    current.rightItem = list.head;
                    last = last.next = list.head = list.head.leftItem = current;
                    ++_itemsCount;
                }
                else
                {
                    current = list.tail;
                    while(current)
                    {
                        if (current.key < key)
                        {
                            auto newItem = new Item(value, key, last);
                            newItem.rightItem = current.rightItem;
                            newItem.leftItem = current;
                            last = last.next = current.rightItem = current.rightItem.leftItem = newItem;
                            ++_itemsCount;
                            break;
                        }
                        else if (current.key == key)
                        {
                            current.data = value;
                            break;
                        }
                        else
                        {
                            current = current.leftItem;
                        }
                    }
                }
                
            }
            else if (list.tail is null)
            {
                list.head = list.tail = new Item(value, key, last);
                ++_itemsCount;
                last = last.next = list.tail;
                
            }
            else
            {
                if (list.tail.key < key)
                {
                    auto newItem = new Item(value, key, last);
                    newItem.leftItem = list.head;
                    list.head.rightItem = list.tail = last = last.next = newItem;
                    ++_itemsCount;
                }
                else if (list.tail.key > key)
                {
                    auto newItem = new Item(value, key, last);
                    newItem.rightItem = list.tail;
                    list.head = list.tail.leftItem = last = last.next = newItem;
                    ++_itemsCount;
                }
                else
                {
                    list.tail.data = value;
                }
            }
        }
    }
    
    VT opIndex(KT key)
    {
        ptrdiff_t keyIndex = getKeyIndex(key);
        auto list = hashTable.ptr + keyIndex;
        
        if (list.tail != list.head)
        {
            if (list.tail.key == key)
            {
                return list.tail.data;
            }
            else if (list.head.key == key)
            {
                return list.head.data;
            }
            else
            {
                auto current = list.tail.leftItem;
                while (current)
                {
                    if (current.key == key)
                    {
                        return current.data;
                    }
                    current = current.leftItem;
                }
            }
            
        }
        else if (list.tail is null)
        {
            return VT.init;
        }
        else
        {
            if (list.tail.key == key)
            {
                return list.tail.data;
            }
        }
        
        return VT.init;
    }
    
    bool remove(KT key)
    {
        ptrdiff_t keyIndex = getKeyIndex(key);
        auto list = hashTable.ptr + keyIndex;
        auto current = list.tail;
        
        while (current)
        {
            if (current.key == key)
            {
                if (current != list.tail && current != list.head)
                {
                    current.leftItem.rightItem = current.rightItem;
                    current.rightItem.leftItem = current.leftItem;
                    current.prev.next = current.next;
                    current.next.prev = current.prev;
                }
                else if (current == list.tail && current == list.head)
                {
                    list.tail = null;
                    list.head = null;
                    if (current == last)
                    {
                        last = current.prev;
                        if (last)
                        {
                            last.next = null;
                        }
                    }
                    
                    if (current == first)
                    {
                        first = current.next;
                        if (first)
                        {
                            first.prev = null;
                        }
                    }
                    
                }
                else if (current == list.tail)
                {
                    list.tail = current.leftItem;
                    list.tail.rightItem = null;
                    
                    if (current == last)
                    {
                        last = current.prev;
                        last.next = null;
                    }
                    else
                    {
                        current.prev.next = current.next;
                        if (current.next)
                        {
                            current.next.prev = current.prev;
                        }
                    }
                    
                }
                else if (current == list.head)
                {
                    list.head = current.rightItem;
                    list.head.leftItem = null;
                    
                    if (current == first)
                    {
                        first = current.next;
                        first.prev = null;
                    }
                    else
                    {
                        current.next.prev = current.prev;
                        if (current.prev)
                        {
                            current.prev.next = current.next;
                        }
                    }
                }
                
                destroy(current);
                return true;
            }
            current = current.leftItem;
        }
        return false;
    }
    
    int opApply(int delegate(KT key, ref VT value) dg)
    {
        int result = 0;
        Item * current = first;
        
        while(current)
        {
            result = dg(current.key, current.data);
            if (result)
            {
                break;
            }
            current = current.next;
            
        }
        return result;
    }
    
    int opApply(int delegate(ref VT value) dg)
    {
        int result = 0;
        Item * current = first;
        
        while(current)
        {
            result = dg(current.data);
            if (result)
            {
                break;
            }
            current = current.next;
            
        }
        return result;
    }
    
    
}


