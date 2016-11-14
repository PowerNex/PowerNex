module data.linkedlist;

class LinkedList(T) {
public:
	void add(T* obj) {
		Node n = new Node(obj, null);
		if (last)
			last.next = n;
		else
			first = n;
		last = n;
		len++;
	}

	T* remove(T* obj) {
		Node prev;
		Node cur = first;
		while (cur && cur.data != obj) {
			prev = cur;
			cur = cur.next;
		}

		if (prev) {
			prev.next = cur.next;
			if (!prev.next)
				last = null;
		} else {
			first = cur.next;
			if (!first)
				last = null;
		}

		cur.destroy;
		len--;
		return obj;
	}

	T* remove(size_t idx) {
		if (idx >= len)
			return null;

		Node prev;
		Node cur = first;
		for (; idx; idx--) {
			prev = cur;
			cur = cur.next;
		}

		if (prev) {
			prev.next = cur.next;
			if (!prev.next)
				last = prev;
		} else {
			first = cur.next;
			if (!first)
				last = null;
		}

		T* data = cur.data;
		cur.destroy;
		len--;
		return data;
	}

	T* get(size_t idx) {
		if (idx >= len)
			return null;

		Node cur = first;
		while (idx-- && cur)
			cur = cur.next;

		if (!cur)
			return null;
		return cur.data;
	}

	@property size_t length() {
		return len;
	}

	T* opIndex(size_t i) {
		return get(i);
	}

	size_t opDollar() {
		return len;
	}

private:
	class Node {
		T* data;
		Node next;
		this(T* data, Node next = null) {
			this.data = data;
			this.next = next;
		}
	}

	Node first;
	Node last;
	size_t len;
}
