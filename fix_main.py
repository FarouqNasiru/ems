"""
The file has TWO occurrences of '// --- WIDGET: WEEKLY PROGRESS ---'.
The FIRST one (at ~line 1534) is NOT followed by the class definition
but instead has orphaned code.
The SECOND one (at ~line 17xx) IS properly followed by the class definition.

Fix: delete everything from first '// --- WIDGET: WEEKLY PROGRESS ---'
up to (but not including) the second '// --- WIDGET: WEEKLY PROGRESS ---'.
"""

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    lines = f.readlines()

total = len(lines)
print(f'Total lines: {total}')

WP_COMMENT = '// --- WIDGET: WEEKLY PROGRESS ---'
AC_COMMENT = '// --- WIDGET: ANALYTICS CHART ---'

wp_occurrences = []
ac_occurrences = []

for i, line in enumerate(lines):
    if WP_COMMENT in line:
        wp_occurrences.append(i)
        print(f'WP comment at L{i+1}: next={repr(lines[i+1][:60]) if i+1<total else "EOF"}')
    if AC_COMMENT in line:
        ac_occurrences.append(i)
        print(f'AC comment at L{i+1}')

print(f'WP occurrences: {[x+1 for x in wp_occurrences]}')
print(f'AC occurrences: {[x+1 for x in ac_occurrences]}')

if len(wp_occurrences) >= 2:
    # Delete from first WP occurrence up to second WP occurrence
    first_wp = wp_occurrences[0]
    second_wp = wp_occurrences[1]
    print(f'Deleting lines {first_wp+1} to {second_wp} (orphaned section)')
    new_lines = lines[:first_wp] + lines[second_wp:]
    with open('lib/main.dart', 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    print(f'Done. New total: {len(new_lines)}')
elif len(wp_occurrences) == 1:
    wp_idx = wp_occurrences[0]
    next_line = lines[wp_idx + 1].strip() if wp_idx + 1 < total else ''
    if next_line.startswith('class WeeklyProgressWidget'):
        print('Single WP comment immediately followed by class - file is clean!')
    else:
        print(f'Single WP comment but NOT followed by class: {repr(next_line[:80])}')
        # Find next proper class or section start
        if ac_occurrences:
            ac_idx = ac_occurrences[0]
            print(f'Deleting lines {wp_idx+2} to {ac_idx} (orphaned code after single WP comment)')
            new_lines = lines[:wp_idx+1] + lines[ac_idx:]
            with open('lib/main.dart', 'w', encoding='utf-8') as f:
                f.writelines(new_lines)
            print(f'Done. New total: {len(new_lines)}')
else:
    print('No WP comment found')
