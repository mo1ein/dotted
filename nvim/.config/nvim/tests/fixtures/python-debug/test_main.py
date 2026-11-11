import unittest

from main import double


class DoubleTests(unittest.TestCase):
    def test_double(self):
        got = double(3)
        self.assertEqual(got, 6)  # BREAKPOINT_TEST


if __name__ == "__main__":
    unittest.main()
