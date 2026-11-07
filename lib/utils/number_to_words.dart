class NumberToWords {
  static String convert(int number) {
    if (number == 0) {
      return 'Zero';
    }

    if (number < 0) {
      return 'Minus ${convert(-number)}';
    }

    final parts = <String>[];

    if (number >= 10000000) {
      parts.add(
        '${convert(number ~/ 10000000)} Crore',
      );
      number %= 10000000;
    }

    if (number >= 100000) {
      parts.add(
        '${convert(number ~/ 100000)} Lakh',
      );
      number %= 100000;
    }

    if (number >= 1000) {
      parts.add(
        '${convert(number ~/ 1000)} Thousand',
      );
      number %= 1000;
    }

    if (number >= 100) {
      parts.add(
        '${convert(number ~/ 100)} Hundred',
      );
      number %= 100;
    }

    if (number > 0) {
      parts.add(_belowHundred(number));
    }

    return parts.join(' ');
  }

  static String _belowHundred(int number) {
    const ones = [
      '',
      'One',
      'Two',
      'Three',
      'Four',
      'Five',
      'Six',
      'Seven',
      'Eight',
      'Nine',
      'Ten',
      'Eleven',
      'Twelve',
      'Thirteen',
      'Fourteen',
      'Fifteen',
      'Sixteen',
      'Seventeen',
      'Eighteen',
      'Nineteen',
    ];

    const tens = [
      '',
      '',
      'Twenty',
      'Thirty',
      'Forty',
      'Fifty',
      'Sixty',
      'Seventy',
      'Eighty',
      'Ninety',
    ];

    if (number < 20) {
      return ones[number];
    }

    if (number % 10 == 0) {
      return tens[number ~/ 10];
    }

    return '${tens[number ~/ 10]} ${ones[number % 10]}';
  }

  static String rupees(double amount) {
    final rupees = amount.floor();
    final paise = ((amount - rupees) * 100).round();

    String result =
        'Rupees ${convert(rupees)}';

    if (paise > 0) {
      result +=
          ' and ${convert(paise)} Paise';
    }

    return '$result Only';
  }
}