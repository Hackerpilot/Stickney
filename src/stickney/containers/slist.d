module stickney.containers.slist;

import stickney.memory.blockallocator;

struct SList(T)
{
	@disable this();
	@disable this(this);

	this(BlockAllocator* allocator)
	{
		if (allocator is null)
		{
			ownAllocator = true;
			import std.conv;
			allocator = cast(BlockAllocator*) .malloc(BlockAllocator.sizeof);
			emplace(allocator, 1024 * 4);
		}
		this.allocator = allocator;
	}

	~this()
	{
		clear();
		if (ownAllocator)
		{
			typeid(BlockAllocator).destroy(allocator);
			.free(allocator);
		}
	}

	void clear()
	{
		allocator.deallocateAll();
		_length = 0;
	}

	void put(T t)
	{
		Node* n = allocateNode();
		n.next = rootNode;
		n.value = t;
		rootNode = n;
		_length++;
	}

	alias insert = put;

	size_t remove(T t)
	{
		size_t count;
		Node* previous = null;
		Node* current = rootNode;
		while (current !is null)
		{
			if (current.value == t)
			{
				if (previous is null)
					rootNode = current.next;
				else
					previous.next = current.next;
				count++;
				_length--;
			}
			else
				previous = current;
			current = current.next;
		}
		return count;
	}

	Range opSlice()
	{
		return Range(rootNode);
	}

	static struct Range
	{
		T front()
		{
			return current.value;
		}

		bool empty() const @property
		{
			return current is null;
		}

		void popFront()
		{
			current = current.next;
		}

		Node* current;
	}

	bool empty() const nothrow pure @property
	{
		return _length == 0;
	}

	size_t length() const nothrow pure @property
	{
		return _length;
	}

private:

	import stickney.memory.blockallocator;

	Node* allocateNode()
	{
		return cast(Node*) allocator.allocate(Node.sizeof);
	}

	static struct Node
	{
		Node* next;
		T value;
	}

	BlockAllocator* allocator;

	bool ownAllocator;

	size_t _length;

	Node* rootNode;
}

///
unittest
{
	import std.range;
	import std.stdio;
	writeln("SList test started");
	SList!int ints = SList!int(null);
	ints.insert(20);
	assert (ints.length == 1);
	assert (equal(ints[], [20]));
	ints.insert(10);
	ints.insert(10);
	ints.insert(10);
	ints.insert(10);
	assert (equal(ints[], [10, 10, 10, 10, 20]));
	assert (ints.length == 5);
	assert (ints.remove(10) == 4);
	assert (ints.length == 1);
	assert (equal(ints[], [20]));
	ints.insert(42);
	ints.remove(20);
	assert (ints.remove(100) == 0);
	ints.remove(42);
	assert (ints.empty);
	writeln("SList test completed");
}

private:

extern(C) nothrow pure @trusted void* malloc(size_t);
extern(C) nothrow pure @trusted void free(void*);
