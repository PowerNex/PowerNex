module Data.LinkedList;

class LinkedList(T : Object) {
public:
	void Add(T t) {
		Node n = new Node(t, null);
		if (last)
			last.next = n;
		else
			first = n;
		last = n;
		len++;
	}

	T Remove(size_t idx) {
		if (idx >= len)
			return null;
		Node prev;
		Node cur = first;
		while (idx && cur) {
			idx--;
			prev = cur;
			cur = cur.next;
		}

		if (!cur)
			return null;

		if (prev) {
			prev.next = cur.next;
			if (!prev.next)
				last = null;
		} else
			first = cur.next;

		T data = cur.data;
		cur.destroy;
		len--;
		return data;
	}

	T Get(size_t idx) {
		if (idx >= len)
			return null;

		Node cur = first;
		while (idx-- && cur)
			cur = cur.next;

		if (!cur)
			return null;
		return cur.data;
	}

	@property size_t Length() {
		return len;
	}

private:
	class Node {
		T data;
		Node next;
		this(T data, Node next = null) {
			this.data = data;
			this.next = next;
		}
	}

	Node first;
	Node last;
	size_t len;
}
