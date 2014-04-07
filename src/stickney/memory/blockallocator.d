module stickney.memory.blockallocator;

//import std.allocator;

/**
 * Allocator that supports quickly allocating items and then freeing them all at
 * once when its destructor is called.
 */
struct BlockAllocator
{
public:
	@disable this();
	@disable this(this);

	/**
	 * Params: blockSize = the size of the blocks to request from malloc at once
	 */
	this(size_t blockSize)
	in
	{
		assert ((blockSize & (blockSize - 1)) == 0, "blockSize must be a power of two");
	}
	body
	{
		this.blockSize = blockSize;
		rootBlock = null;
	}

	~this()
	{
		deallocateAll();
	}

	/**
	 * Frees all memory held by this allocator.
	 */
	void deallocateAll()
	{
		Block* previous = void;
		Block* current = rootBlock;
		while (current !is null)
		{
			previous = current;
			current = current.next;
			free(previous);
//			import std.c.stdio;
//			fprintf(stderr, "Block freed\n");
		}
		rootBlock = null;
	}

	/**
	 * Allocates the given number of bytes
	 */
	void[] allocate(size_t byteCount)
	in
	{
		assert (byteCount <= (blockSize - Block.sizeof));
	}
	body
	{
		for (Block* current = rootBlock; current !is null; current = current.next)
		{
			void[] mem = allocateInBlock(current, byteCount);
			if (mem is null)
				continue;
			return mem;
		}
		Block* b = allocateNewBlock();
		b.next = rootBlock;
		rootBlock = b;
		return allocateInBlock(rootBlock, byteCount);
	}

	enum padding = Block.sizeof;

private:

	void[] allocateInBlock(Block* block, size_t byteCount)
	{
		if (block.used + byteCount > block.memory.length)
			return null;
		immutable oldUsed = block.used;
		immutable newUsed = oldUsed + byteCount;
		block.used = roundUpToMultipleOf(newUsed, platformAlignment);
		return block.memory[oldUsed .. newUsed];
	}

	Block* allocateNewBlock()
	{
//		import std.c.stdio;
//		fprintf(stderr, "%d-byte block allocated\n", blockSize);
		void* mem = malloc(blockSize);
		Block* block = cast(Block*) mem;
		block.used = roundUpToMultipleOf(Block.sizeof, platformAlignment);
		block.next = null;
		block.memory = mem[0 .. blockSize];
		return block;
	}

	static struct Block
	{
		size_t used;
		Block* next;
		void[] memory;
	}

	size_t roundUpToMultipleOf(size_t s, uint base)
	{
		assert(base);
		auto rem = s % base;
		return rem ? s + base - rem : s;
	}

	immutable size_t blockSize;
	Block* rootBlock;
}

unittest
{
	import std.stdio;
	import std.string;
	writeln("BlockAllocator test started");
	static assert (BlockAllocator.Block.sizeof == (size_t.sizeof + (void*).sizeof + (void[]).sizeof));
	BlockAllocator b = BlockAllocator(1024 * 4);
	foreach (i; 0 .. 100)
		void[] mem = b.allocate(1_000);
	b.deallocateAll();
	void[] a = b.allocate(20);
	assert (a.length == 20);
	writeln("BlockAllocator test completed");
}

private:

import std.algorithm;
enum uint platformAlignment = max(double.alignof, real.alignof);
extern(C) nothrow pure @trusted void* malloc(size_t);
extern(C) nothrow pure @trusted void free(void*);
