#include <iostream>
#include <vector>
#include <string>
#include <cmath>
#include <algorithm>
#include <utility>
using namespace std;

vector<size_t> get_fixed(bool show, vector<double>& fixed_a, vector<double>& fixed_b);
double num_solutions(size_t a, size_t b, const vector<size_t>& num, const vector<double>& p_A, const vector<double>& p_B);
void grid_search(size_t a, size_t b, const vector<size_t>& num, const vector<double>& fixed_a, const vector<double>& fixed_b, size_t steps);

int main(int argc, char ** argv) {
  bool show = true;
  if (argc == 2 && string(argv[1]) == "-q") {
    show = false;
  }

  size_t sizeA, sizeB;
  if (show)
    cout << "Source universe size: ";
  cin >> sizeA;
  if (show)
    cout << "Target universe size: ";
  cin >> sizeB;

  if (sizeA > sizeB) {
    cerr << "Error: the source universe must be smaller than the target universe" << endl;
    exit(1);
  }

  vector<double> fixed_a, fixed_b;
  vector<size_t> num_preds = get_fixed(show, fixed_a, fixed_b);

  if (show)
    cout << "Grid steps (delta = 1/steps): ";
  size_t steps;
  cin >> steps;

  grid_search(sizeA, sizeB, num_preds, fixed_a, fixed_b, steps);

  return 0;
}

vector<size_t> get_fixed(bool show, vector<double>& fixed_a, vector<double>& fixed_b) {
  size_t n;
  double p;
  vector<size_t> num_preds;

  if (show)
    cout << "Max arity relation: ";
  cin >> n;
  num_preds.resize(n + 1);
  fixed_a.resize(n + 1, 0);
  fixed_b.resize(n + 1, 0);

  for (size_t i = 0; i < num_preds.size(); ++i) {
    if (show)
      cout << "Number of relations with arity " << i << " : ";
    cin >> n;
    num_preds[i] = n;
    if (n) {
      if (show)
        cout << "Fixed Probability of source structure relations with arity " << i << " (0 for not-fixed): ";
      cin >> p;
      fixed_a[i] = p;
      if (show)
        cout << "Fixed Probability of target structure relations with arity " << i << " (0 for not-fixed): ";
      cin >> p;
      fixed_b[i] = p;
    }
  }

  return num_preds;
}

double num_solutions(size_t a, size_t b, const vector<size_t>& num, const vector<double>& p_A, const vector<double>& p_B) {
  double solutions = 1;
  for (size_t i = 0; i < a; ++i) {
    solutions *= (b - i);
  }

  size_t power = 1;
  for (size_t i = 0; i < num.size(); ++i) {
    size_t exp = num[i] * power;

    solutions *= pow(p_A[i] * (p_B[i] - 1) + 1, exp);
//    solutions *= pow(p_B[i], p_A[i] * exp);

    power *= a;
  }
  return solutions;
}

void update_prob(size_t ind, const vector<size_t>& num, vector<double>& a, vector<double>& b, const vector<double>& fa, const vector<double>& fb, size_t steps) {
  for (size_t i = 0, n; ind != 0; ++i) {
    if (num[i / 2] == 0) continue;
    if (i % 2 && fb[i / 2]) {
      b[i / 2] = fb[i / 2];
      continue;
    }
    if (i % 2 == 0 && fa[i/2]) {
      a[i / 2] = fa[i / 2];
      continue;
    }
    n = ind % (steps + 1);
    ind /= (steps + 1);
    if (i % 2) {
      b[i / 2] = (1.0 * n) / steps;
    } else {
      a[i / 2] = (1.0 * n) / steps;
    }
  }
}

void grid_search(size_t a, size_t b, const vector<size_t>& num, const vector<double>& fixed_a, const vector<double>& fixed_b, size_t steps) {
  int n = 0;
  for (size_t i = 0; i < num.size(); ++i) {
    if (num[i] && !fixed_a[i]) {
      ++n;
    }
    if (num[i] && !fixed_b[i]) {
      ++n;
    }
  }

  vector<double> solutions(pow(steps + 1, n));
  vector<double> prob_a, prob_b;
  prob_a.resize(num.size(), 0);
  prob_b.resize(num.size(), 0);

  for (size_t i = 0; i < solutions.size(); ++i) {
    update_prob(i, num, prob_a, prob_b, fixed_a, fixed_b, steps);
    solutions[i] = log(num_solutions(a, b, num, prob_a, prob_b));
  }

  vector<pair<int, int>> points;

  for (size_t ind = 0, dim = 0, step = 1; dim < n; ++ind) { // for each non-empty dimension
    if (num[ind / 2] == 0) continue;

    size_t next_step = step * (steps + 1);
    double last_sol = 0;
    size_t last_ind = 0;
    for (size_t i = 0; i < solutions.size(); i += next_step) {
      for (size_t j = 0; j < step; ++j) {
        for (size_t k = 0; k < (steps + 1); ++k) {
          size_t l = i + j + k * step;
          double sol = solutions[l];
          if (last_sol * sol < 0) {
            points.emplace_back(last_ind, l);
          }
          last_sol = sol;
          last_ind = l;
        }
        last_sol = 0;
      }
    }

    step = next_step;
    ++dim;
  }

  vector<double> prob_a2, prob_b2;
  for (size_t i = 0; i < points.size(); ++i) {
    prob_a.clear(); prob_b.clear();
    prob_a2.clear(); prob_b2.clear();
    prob_a.resize(num.size(), 0); prob_b.resize(num.size(), 0);
    prob_a2.resize(num.size(), 0); prob_b2.resize(num.size(), 0);
    update_prob(points[i].first, num, prob_a, prob_b, fixed_a, fixed_b, steps);
    update_prob(points[i].second, num, prob_a2, prob_b2, fixed_a, fixed_b, steps);
    cout << points[i].first << " " << points[i].second << " ";
    for (size_t j = 0; j < num.size(); ++j) {
      prob_a[j] += prob_a2[j];
      prob_a[j] /= 2;
      prob_b[j] += prob_b2[j];
      prob_b[j] /= 2;
      cout << j << " " << num[j] << " " << prob_a[j] << " " << prob_b[j] << " ";
    }
    cout << num_solutions(a, b, num, prob_a, prob_b) << endl;
  }
}
