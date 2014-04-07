module stickney.containers.hashset;

import stickney.memory.blockallocator;
import stickney.containers.slist;


struct HashSet(T)
{
	@disable this();
	@disable this(this);

	this(size_t bucketCount, size_t blockSize = 1024)
	in
	{
		assert ((bucketCount & (bucketCount - 1)) == 0, "bucketCount must be a power of two");
	}
	body
	{
		import std.conv;
		allocator = cast(BlockAllocator*) .malloc(BlockAllocator.sizeof);
		emplace(allocator, blockSize);
		buckets = (cast(Bucket*) .malloc(bucketCount * (SList!T).sizeof))[0 .. bucketCount];
		foreach (ref bucket; buckets)
			emplace(&bucket, allocator);
	}

	~this()
	{
		foreach (ref bucket; buckets)
			typeid(Bucket).destroy(&bucket);
		.free(buckets.ptr);
		typeid(BlockAllocator).destroy(allocator);
		.free(allocator);
	}

	bool contains(T value)
	{
		size_t hashCode = calculateHash(value);
		size_t index = hashToIndex(hashCode);
		if (buckets[index].empty)
			return false;
		foreach (ref item; buckets[index][])
		{
			if (item.hashCode == hashCode && item.value == value)
				return true;
		}
		return false;
	}

	void insert(T value)
	{
//		import std.stdio;
		size_t hashCode = calculateHash(value);
		size_t index = hashToIndex(hashCode);
		foreach (ref item; buckets[index][])
		{
			if (item.hashCode == hashCode && item.value == value)
				return;
		}
		buckets[index].insert(Node(hashCode, value));
		_length++;
		immutable float ratio = (cast(float) _length / cast(float) buckets.length);
//		writeln(ratio, " ", _length, " ", buckets.length);
		if (ratio > 1.66)
			rehash();
	}

	bool remove(T value)
	{
		size_t hashCode = calculateHash(value);
		size_t index = hashToIndex(hashCode);
		size_t removed = buckets[index].remove(Node(hashCode, value));
		if (removed > 0)
		{
			_length--;
			return true;
		}
		return false;
	}

	/// ditto
	alias put = insert;

	bool empty() const pure nothrow @property
	{
		return _length == 0;
	}

	size_t length() const pure nothrow @property
	{
		return _length;
	}

	void clear()
	{
		foreach (ref bucket; buckets)
		{
			bucket.clear();
		}
	}

	Range opSlice()
	{
		return Range(&this);
	}

	auto opBinaryRight(string op)(T value) if (op == "~=")
	{
		insert(value);
		return this;
	}

	static struct Range
	{
		this(HashSet* hashSet)
		{
			this.hashSet = hashSet;
			range = hashSet.buckets[bucketIndex][];
			while (range.empty && bucketIndex + 1 < hashSet.buckets.length)
			{
				bucketIndex++;
				range = hashSet.buckets[bucketIndex][];
			}
		}

		T front()
		{
			return range.front.value;
		}

		bool empty()
		{
			return bucketIndex >= hashSet.buckets.length;
		}

		void popFront()
		{
			range.popFront();
			while (range.empty && bucketIndex < hashSet.buckets.length)
			{
				bucketIndex++;
				range = hashSet.buckets[bucketIndex][];
			}
		}

	private:
		HashSet!(T)* hashSet;
		size_t bucketIndex;
		SList!(Node).Range range = void;
	}

private:

	import stickney.containers.slist;

	size_t hashToIndex(size_t hash)
	{
		return hash & (buckets.length - 1);
	}

	size_t calculateHash(T value)
	{
		import core.internal.hash;
		size_t h = hashOf(value);
		h ^= (h >>> 20) ^ (h >>> 12);
		return h ^ (h >>> 7) ^ (h >>> 4);
	}

	void rehash()
	{
		import std.conv;
		auto newAllocator = cast(BlockAllocator*) .malloc(BlockAllocator.sizeof);
		emplace(newAllocator, allocator.blockSize);
		immutable newBucketCount = buckets.length << 1;
		Bucket[] oldBuckets = buckets;
		buckets = (cast(Bucket*) .malloc(newBucketCount
			* Bucket.sizeof))[0 .. newBucketCount];
		foreach (ref bucket; buckets)
			emplace(&bucket, newAllocator);
		foreach (ref Bucket bucket; oldBuckets)
		{
			foreach (ref Node item; bucket[])
			{
				buckets[hashToIndex(item.hashCode)].insert(
					Node(item.hashCode, item.value));
			}
			typeid(Bucket).destroy(&bucket);
		}
		.free(oldBuckets.ptr);
		typeid(BlockAllocator).destroy(allocator);
		.free(allocator);
		allocator = newAllocator;
	}

	static struct Node
	{
		size_t hashCode;
		T value;
	}

	alias Bucket = SList!Node;

	Bucket[] buckets;

	BlockAllocator* allocator;

	size_t _length;
}

///
unittest
{
	import std.algorithm;
	import std.stdio;
	import std.uuid;
	writeln("HashSet test started");
	auto strings = HashSet!string(16);
	assert (strings.empty);
	strings.put("test");
	assert (!strings.contains("1234"));
	assert (strings.contains("test"));
	assert (strings.length == 1);
	strings.put("value");
	strings.put("value");
	assert (strings.length == 2);
	assert (canFind(strings[], "test"));
	assert (canFind(strings[], "value"));
	strings.remove("value");
	assert (!strings.contains("value"));
	assert (strings.length == 1);
	strings.remove("not_present");
	assert (strings.length == 1);
	strings.clear();
	foreach (i; 0 .. 1_000)
	{
		strings.insert(randomUUID().toString());
	}
	writeln("HashSet test completed");
}

private:

extern(C) nothrow pure @trusted void* malloc(size_t);
extern(C) nothrow pure @trusted void free(void*);
