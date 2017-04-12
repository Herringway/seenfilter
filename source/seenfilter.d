module seenfilter;
import std.typecons;
import std.range;
import std.traits;
import std.algorithm;

alias AutoAdd = Flag!"autoAdd";

struct ID {
	string db;
	string id;
}
auto seenFilter(AutoAdd autoAdd, T, U)(T data, U inStorage) if (isInputRange!T && hasIDs!(ElementType!T)) {
	static struct SeenFilter {
		T range;
		U storage;
		bool empty()() {
			return range.empty;
		}
		auto ref front()() {
			return range.front;
		}
		void popFront()() {
			do {
				static if (autoAdd == AutoAdd.yes)
					foreach (id; range.front.allIDs.filter!(x => (x.db !in storage) || !storage[x.db].canFind(x.id)))
						storage[id.db] ~= id.id;
				range.popFront();
			} while (!range.empty && range.front.allIDs.seenBefore(storage));
		}
		this()(T inRange, U inStorage) {
			range = inRange;
			storage = inStorage;
			while(!range.empty && range.front.allIDs.seenBefore(storage))
				popFront();
		}
	}
	return SeenFilter(data, inStorage);
}
auto allIDs(T)(T input) if (hasIDs!T) {
	static if (hasMember!(T, "ids")) {
		return input.ids;
	} else static if (hasMember!(T, "id")) {
		return only(input.id);
	} else
		static assert(0);
}
bool seenBefore(T, U)(T data, ref U storage) if (isInputRange!T) {
	return data.filter!(x => (x.db !in storage) || !storage[x.db].canFind(x.id)).empty;
}
template hasIDs(T) {
	static if (hasMember!(T, "ids"))
		enum hasIDs = ((is(ElementType!(typeof(__traits(getMember, T, "ids"))) == ID)) || isCallable!(__traits(getMember, T, "ids")) && is(ElementType!(ReturnType!(typeof(__traits(getMember, T, "ids")))) == ID));
	else static if (hasMember!(T, "id"))
		enum hasIDs = (is(typeof(__traits(getMember, T, "id")) == ID)) || (isCallable!(__traits(getMember, T, "id")) && is(ReturnType!(typeof(__traits(getMember, T, "id"))) == ID));
	else
		enum hasIDs = false;
}
@safe pure nothrow unittest {
	string[][string] storage;
	struct TestData {
		ID id;
		string b;
	}
	struct MultiTestData {
		ID[] ids;
	}
	struct TestFunction {
		string id;
		bool yes;
		ID[] ids() nothrow @safe pure {
			auto output = [ID("t", id)];
			if (yes) {
				output ~= ID("t", "b");
			}
			return output;
		}
	}
	static assert(hasIDs!TestFunction);
	static assert(hasIDs!MultiTestData);
	static assert(hasIDs!TestData);
	auto testData = [TestData(ID("test", "a")), TestData(ID("test", "b")), TestData(ID("test", "b"))];
	assert(testData.seenFilter!(AutoAdd.no)(storage).walkLength == 3);
	assert(testData.seenFilter!(AutoAdd.yes)(storage).walkLength == 2);
	assert(testData.seenFilter!(AutoAdd.yes)(["test": ["a", "b"]]).walkLength == 0);

	auto storage2 = storage.init;
	auto testData2 = [MultiTestData([ID("test", "a")]), MultiTestData([ID("test", "b")]), MultiTestData([ID("test", "a"), ID("test", "b")])];
	assert(testData2.seenFilter!(AutoAdd.no)(storage2).walkLength == 3);
	assert(testData2.seenFilter!(AutoAdd.yes)(storage2).walkLength == 2);

	foreach (ref a; testData.seenFilter!(AutoAdd.no)(storage.init))
		a.b = "hello";

	foreach (testDatum; testData)
		assert(testDatum.b == "hello");

	auto storage3 = storage.init;
	auto testData3 = [TestFunction("1"), TestFunction("b")];
	uint count;
	foreach (ref t; testData3.seenFilter!(AutoAdd.yes)(storage3)) {
		t.yes = true;
		count++;
	}
	assert(count == 1);
}