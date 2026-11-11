package main

import "fmt"

func double(n int) int {
	result := n * 2
	return result
}

func main() {
	value := 21
	result := double(value) // BREAKPOINT_MAIN
	fmt.Println(result)     // BREAKPOINT_AFTER
}
