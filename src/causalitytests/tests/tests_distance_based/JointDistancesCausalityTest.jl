import Distances: SqEuclidean
import HypothesisTests: OneSampleTTest

"""
    JointDistancesCausalityTest

The supertype of all joint distance distribution tests.
"""
abstract type JointDistancesCausalityTest{N} <: DistanceBasedCausalityTest{N} end

export JointDistancesCausalityTest