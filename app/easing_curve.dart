/**
 * <easing_curve.dart>
 * 
 * Copyright (c) 2014 "Adam Stark"
 * 
 * This file is part of Pomeranian Chrome.
 * 
 * Pomeranian Chrome is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 * 
 */

library easing_curve;

class EasingCurve {
  final List<double> polynomialTerms;
  final double cTerm;
  EasingCurve (List<double> points, {double this.cTerm: 0.0}) : 
    polynomialTerms = BezierPolynomial.getTTerms(points);
  EasingCurve.raw (List<double> this.polynomialTerms, {double this.cTerm: 0.0});
  double operator [] (double t) {
    double result = 0.0;
    for (var p in polynomialTerms)
      result = (result + p)*t;
    return result + cTerm;
  }
  
  static EasingCurve _LINEAR = null;
  static EasingCurve _CUBIC_EASE_IN_OUT = null;
  static EasingCurve _QUINTIC_EASE_IN_OUT = null;
  
  static EasingCurve get LINEAR {
    if (_LINEAR == null)
      _LINEAR = new EasingCurve([]);
    return _LINEAR;
  }
  static EasingCurve get CUBIC_EASE_IN_OUT {
    if (_CUBIC_EASE_IN_OUT == null)
      _CUBIC_EASE_IN_OUT = new EasingCurve([0.0,1.0]);
    return _CUBIC_EASE_IN_OUT;
  }
  static EasingCurve get QUINTIC_EASE_IN_OUT {
    if (_QUINTIC_EASE_IN_OUT == null)
      _QUINTIC_EASE_IN_OUT = new EasingCurve([0.0,0.0,1.0,1.0]);
    return _QUINTIC_EASE_IN_OUT;
  }
  
  EasingCurve derivative() {
    var newPolyTerms = new List();
    var polyIterator = polynomialTerms.iterator;
    for (var factor = polynomialTerms.length; factor > 1; factor--) {
      polyIterator.moveNext();
      newPolyTerms.add(factor.toDouble()*polyIterator.current);
    }
    polyIterator.moveNext();
    return new EasingCurve.raw(newPolyTerms,cTerm:polyIterator.current);
  }
  @override toString () => "(new EasingCurve ($polynomialTerms, cTerm: $cTerm))";
}

class BezierPolynomial {
  static _BezierGen generator = new _BezierGen();
  static List<num> getTTerms(List<num> pTerms) {
    var i      = pTerms.length;
    var matrix = generator[i + 1];
    List<num> results = new List();
    num linTerm = 0;
    for (var j = 0; j < i; j++) {
      num tTerm = pTerms[0] - pTerms[0];
      for (var k = i; k >= j && k > 0; k--) {
        tTerm += matrix[j][k]*pTerms[i - k];
      }
      if (j==0)
        tTerm += matrix[j][0];
      linTerm -= tTerm;
      results.add(tTerm);
    }
    results.add(linTerm + 1);
    return results;
  }
}
class _BezierGen {
  final List<List<List<int>>> _generators = new List();
  _BezierGen() {
    _generators.add([[1]]);
  }
  void addMatrix () {
    var i = _generators.length;
    List<List<int>> rows = new List();
    
    List<int> currentRow = _generators[i-1][0];
    List<int> previousRow = 
        new List.from(currentRow.map((_) => 0), growable: false);
    
    for (var j = 0; j < i; j++) {
      currentRow = _generators[i-1][j];
      List<int> row = new List();
      row.add(currentRow[0]);
      for (var k=1; k < i; k++) {
        row.add(previousRow[k-1] + currentRow[k] - currentRow[k-1]);
      }
      row.add(previousRow[i-1] - currentRow[i-1]);
      
      rows.add(row);
      previousRow = currentRow;
    }
    
    List<int> row = new List();
    row.add(0);
    for (var k=1; k <= i; k++) {
      row.add(previousRow[k-1]);
    }
    rows.add(row);
    _generators.add(rows);

  }
  List<List<int>> operator [](int index) {
    var length = _generators.length;
    if (index < length) return _generators[index];
    for (var i = length;i <= index;i++)
      addMatrix();
    return _generators[index];
  }
}