.PHONY: coro corodel

coro:
	cd .. && make -e NAME=slave1.tsand.org ROLE=coro node
	cd .. && make -e NAME=slave2.tsand.org ROLE=coro node
	cd .. && make -e NAME=slave3.tsand.org ROLE=coro node


corodel:
	cd .. && make -e NAME=slave1.tsand.org Delete
	cd .. && make -e NAME=slave2.tsand.org Delete
	cd .. && make -e NAME=slave3.tsand.org Delete
