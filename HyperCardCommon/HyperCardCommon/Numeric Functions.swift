//
//  Tools.swift
//  HyperCard
//
//  Created by Pierre Lorenzi on 18/02/2016.
//  Copyright © 2016 Pierre Lorenzi. All rights reserved.
//



func downToMultiple<A: BinaryInteger>(_ n: A, _ multiple: A) -> A {
    return n - n % multiple
}

func upToMultiple<A: BinaryInteger>(_ n: A, _ multiple: A) -> A {
    return n - 1 - (n - 1) % multiple + multiple
}


/* Used in checksums */
func rotateRight3Bits(_ n: UInt32) -> UInt32 {
    let end = n & 0b111
    return (n >> 3) | (end << 29)
}
