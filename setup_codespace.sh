#!/bin/bash
# Run inside the Codespace (Periodic Table Database)
# Run it from the root folder of the CodeRoad workspace for this project
set -e
echo "Working in: $(pwd)"
if psql -U freecodecamp -d periodic_table -tAc "SELECT 1 FROM information_schema.columns WHERE table_name='properties' AND column_name='weight'" | grep -q 1
then
psql -U freecodecamp -d periodic_table -v ON_ERROR_STOP=1 <<'SQL'
ALTER TABLE properties RENAME COLUMN weight TO atomic_mass;
ALTER TABLE properties RENAME COLUMN melting_point TO melting_point_celsius;
ALTER TABLE properties RENAME COLUMN boiling_point TO boiling_point_celsius;
ALTER TABLE properties ALTER COLUMN melting_point_celsius SET NOT NULL;
ALTER TABLE properties ALTER COLUMN boiling_point_celsius SET NOT NULL;
ALTER TABLE elements ADD UNIQUE(symbol);
ALTER TABLE elements ADD UNIQUE(name);
ALTER TABLE elements ALTER COLUMN symbol SET NOT NULL;
ALTER TABLE elements ALTER COLUMN name SET NOT NULL;
ALTER TABLE properties ADD FOREIGN KEY(atomic_number) REFERENCES elements(atomic_number);
CREATE TABLE types(type_id INT PRIMARY KEY, type VARCHAR(20) NOT NULL);
INSERT INTO types(type_id, type) VALUES (1, 'metal'), (2, 'nonmetal'), (3, 'metalloid');
ALTER TABLE properties ADD COLUMN type_id INT REFERENCES types(type_id);
UPDATE properties p SET type_id = t.type_id FROM types t WHERE p.type = t.type;
ALTER TABLE properties ALTER COLUMN type_id SET NOT NULL;
UPDATE elements SET symbol = UPPER(LEFT(symbol, 1)) || SUBSTRING(symbol FROM 2);
ALTER TABLE properties ALTER COLUMN atomic_mass TYPE DECIMAL;
UPDATE properties SET atomic_mass = TRIM(TRAILING '0' FROM atomic_mass::TEXT)::DECIMAL;
INSERT INTO elements(atomic_number, symbol, name) VALUES (9, 'F', 'Fluorine'), (10, 'Ne', 'Neon');
INSERT INTO properties(atomic_number, type, atomic_mass, melting_point_celsius, boiling_point_celsius, type_id) VALUES (9, 'nonmetal', 18.998, -220, -188.1, 2), (10, 'nonmetal', 20.18, -248.6, -246.1, 2);
DELETE FROM properties WHERE atomic_number = 1000;
DELETE FROM elements WHERE atomic_number = 1000;
ALTER TABLE properties DROP COLUMN type;
SQL
fi
rm -rf periodic_table && mkdir periodic_table && cd periodic_table
git init -q -b main 2>/dev/null || { git init -q; git checkout -q -b main; }
if [[ -z $(git config user.name) ]]; then GIT="git -c user.name=skypro1111 -c user.email=skypro1111@users.noreply.github.com"; else GIT=git; fi
printf '#!/bin/bash\n' > element.sh && chmod +x element.sh
$GIT add . && $GIT commit -qm "Initial commit"
printf '#!/bin/bash\n\nPSQL="psql -X --username=freecodecamp --dbname=periodic_table -t --no-align -c"\n' > element.sh
$GIT commit -qam "feat: add psql variable"
printf '#!/bin/bash\n\nPSQL="psql -X --username=freecodecamp --dbname=periodic_table -t --no-align -c"\n\nif [[ -z $1 ]]\nthen\n  echo "Please provide an element as an argument."\n  exit\nfi\n' > element.sh
$GIT commit -qam "feat: require an element argument"
cat > element.sh <<'SCRIPT'
#!/bin/bash

PSQL="psql -X --username=freecodecamp --dbname=periodic_table -t --no-align -c"

if [[ -z $1 ]]
then
  echo "Please provide an element as an argument."
  exit
fi

if [[ $1 =~ ^[0-9]+$ ]]
then
  CONDITION="e.atomic_number = $1"
else
  CONDITION="e.symbol = '$1' OR e.name = '$1'"
fi

ELEMENT=$($PSQL "SELECT e.atomic_number, e.name, e.symbol, t.type, p.atomic_mass, p.melting_point_celsius, p.boiling_point_celsius FROM elements e JOIN properties p USING(atomic_number) JOIN types t USING(type_id) WHERE $CONDITION")

if [[ -z $ELEMENT ]]
then
  echo "I could not find that element in the database."
  exit
fi

IFS="|" read NUMBER NAME SYMBOL TYPE MASS MELTING BOILING <<< "$ELEMENT"
echo "The element with atomic number $NUMBER is $NAME ($SYMBOL). It's a $TYPE, with a mass of $MASS amu. $NAME has a melting point of $MELTING celsius and a boiling point of $BOILING celsius."
SCRIPT
$GIT commit -qam "feat: look up element by number, symbol or name"
echo "# Periodic Table" > README.md && $GIT add README.md && $GIT commit -qm "chore: add readme"
echo "Element lookup script for the periodic_table database." >> README.md && $GIT commit -qam "chore: describe project in readme"
git status --short; git log --oneline
echo "periodic_table ready. Now click Run in CodeRoad."
