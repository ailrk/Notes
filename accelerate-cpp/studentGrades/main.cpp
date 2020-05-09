#include <iostream>
#include <algorithm>
#include <iomanip>
#include <ios>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>
#include "student_info.hpp"
#include "grade.hpp"

using std::cin;
using std::cout;
using std::domain_error;
using std::endl;
using std::max;
using std::string;
using std::vector;

int main() {
    vector<Student_info> students;
    Student_info record;
    string::size_type maxlen = 0;

    while (read(cin, record)) {
        maxlen = max(maxlen, record.name.size());
        students.push_back(record);
    }

    sort(students.begin(), students.end(), compare);
    for (vector<Student_info>::size_type i = 0; i != students.size(); ++i) {
        cout << students[i].name
            << string(maxlen + 1 - students[i].name.size(), ' ');
        try {
            double final_grade = grade(students[i]);
            std::streamsize prec = cout.precision();
            cout << std::setprecision(3) << final_grade
                << std::setprecision(prec);

        } catch (std::domain_error& e) {
            cout << e.what();
        }
        cout << endl;
    }

    return 0;
}
