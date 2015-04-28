module util.orderedaa;

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
        Item* left = null, right = null;
        byte move;
    }
    
    struct Item
    {
        VT data;
        KT key;
        
        static void[] heap;
        enum preAllocatedCount = 7;
        
        Item* prev = null, next = null, followItem = null;
        
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
                GC.addRange(p, VT.sizeof);
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
    
    List* hashTable = null;
    
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
        
        hashTable = cast(List *)p;
        
        static if (is(T[0] == KT) && is(T[1] == VT))
        {
            ptrdiff_t i = getKeyIndex(args[0]);
            key = args[0];
            Item *item = new Item(args[1], key, null);
            (hashTable + i).left = item;
            (hashTable + i).right = item;
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
            core.stdc.stdlib.free(hashTable);
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
        auto list = hashTable + keyIndex;

        if (list.left.key >= key)
        {
            Item* current = list.left;
            while (current && key >= current.key)
            {
                if (current.key == key)
                {
                    return &(current.data);
                }
                current = current.followItem;
            }
        }
        else
        {
            Item* current = list.right;
            while (current && key <= current.key)
            {
                if (current.key == key)
                {
                    return &(current.data);
                }
                current = current.followItem;
            }
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
            if (hashTable is null)
            {
                auto p = core.stdc.stdlib.calloc(hashTableSize, List.sizeof);
                if (!p)
                {
                    throw new OutOfMemoryError();
                }
                hashTable = cast(List *)p;
            }
            ptrdiff_t keyIndex = getKeyIndex(key);
            auto list = hashTable + keyIndex;
            Item * current = void;
            first = last = list.left = list.right = new Item(value, key, last);
            ++_itemsCount;
            
        }
        else
        {
            ptrdiff_t keyIndex = getKeyIndex(key);
            
            auto list = hashTable + keyIndex;
            Item * current = void;
            
            if (list.left != list.right)
            {
                if (key >= list.right.key)
                {
                    current = list.right;
                    if (current.key == key)
                    {
                        current.data = value;
                        return;
                    }
                    while(current.followItem)
                    {
                        if (current.key == key)
                        {
                            current.data = value;
                            return;
                        }
                        else if (key < current.followItem.key)
                        {
                            break;
                        }
                        current = current.followItem;
                    }

                    auto newItem = new Item(value, key, last);
                    newItem.followItem = current.followItem;
                    last = last.next = current.followItem = newItem;
                    ++_itemsCount;
                    auto tmpItem = list.right.followItem;
                    list.right.followItem = list.left;
                    list.left = list.right;
                    list.right = tmpItem;
                }
                else if (key <= list.left.key)
                {
                    current = list.left;
                    if (current.key == key)
                    {
                        current.data = value;
                        return;
                    }
                    while(current.followItem)
                    {
                        if (current.key == key)
                        {
                            current.data = value;
                            return;
                        }
                        else if (key > current.followItem.key)
                        {
                            break;
                        }
                        current = current.followItem;
                    }

                    auto newItem = new Item(value, key, last);
                    newItem.followItem = current.followItem;
                    last = last.next = current.followItem = newItem;
                    ++_itemsCount;
                    auto tmpItem = list.left.followItem;
                    list.left.followItem = list.right;
                    list.right = list.left;
                    list.left = tmpItem;
                }
                else
                {
                    auto newItem = new Item(value, key, last);
                    ++_itemsCount;
                    
                    switch (list.move)
                    {
                        case 1:
                        case 2:
                            newItem.followItem = list.left;
                            list.left = last = last.next = newItem;
                            --list.move;
                            break;
                        default:
                            newItem.followItem = list.right;
                            list.right = last = last.next = newItem;
                            ++list.move;
                    }
                    
                }
                
            }
            else if (list.left is null)
            {
                list.left = list.right = new Item(value, key, last);
                ++_itemsCount;
                last = last.next = list.left;
                
            }
            else
            {
                if (key == list.left.key)
                {
                    list.left.data = value;
                    return;
                }
                current = new Item(value, key, last);
                if (list.left.key > key)
                {
                    list.left = current;
                }
                else
                {
                    list.right = current;
                }

                last = last.next = current;
                ++_itemsCount;
            }
        }
    }

    VT opIndex(KT key)
    {
        ptrdiff_t keyIndex = getKeyIndex(key);
        auto list = hashTable + keyIndex;
        Item* current = void;
        
        if (list.left != list.right)
        {
            if (key == list.right.key)
            {
                return list.right.data;
            }
            else if (key == list.left.key)
            {
                return list.left.data;
            }
            else if (key < list.left.key)
            {
                current = list.left.followItem;
                while(current && current.key >= key)
                {
                    if (current.key == key)
                    {
                        return current.data;
                    }
                    current = current.followItem;
                }
            }
            else if (key > list.right.key)
            {
                current = list.right.followItem;
                while(current && current.key <= key)
                {
                    if (current.key == key)
                    {
                        return current.data;
                    }
                    current = current.followItem;
                }
            }
            else if (key < list.right.key && key > list.left.key)
            {
                return VT.init;
            }
        }
        else if (list.left is null)
        {
            return VT.init;
        }
        else
        {
            if (list.left.key == key)
            {
                return list.left.data;
            }
        }
        
        return VT.init;
    }

    bool remove(KT key)
    {
        /*ptrdiff_t keyIndex = getKeyIndex(key);
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
         }*/
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


