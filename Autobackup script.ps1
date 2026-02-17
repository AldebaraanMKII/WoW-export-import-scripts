# Install required module if not already installed
if (-not (Get-Module -ListAvailable -Name SimplySql)) {
    Install-Module -Name SimplySql -Force
}
if (-not (Get-Module -ListAvailable -Name PSSQLite)) {
	Install-Module -Name PSSQLite -Force
}
########################################
# Import the modules
Import-Module SimplySql
Import-Module PSSQLite
########################################
. "$PSScriptRoot/(Config) Backup scripts.ps1"	# import configuration
. "$PSScriptRoot/(Config) AutoBackup script.ps1"	# import configuration
. "$PSScriptRoot/_functions/Utility.ps1"
. "$PSScriptRoot/_functions/Characters-Backup.ps1"
. "$PSScriptRoot/_functions/Characters-Restore.ps1"
. "$PSScriptRoot/_functions/Guilds-Backup.ps1"
. "$PSScriptRoot/_functions/Guilds-Restore.ps1"
. "$PSScriptRoot/_functions/FusionGEN-Backup.ps1"
. "$PSScriptRoot/_functions/FusionGEN-Restore.ps1"
########################################

########################################
#create database file if it doesn`t exist
if (-not (Test-Path $DBFilePath)) {
    $createTableQuery = "
    CREATE TABLE Characters (
        name TEXT NOT NULL PRIMARY KEY,
        guid INTEGER,
        accountName TEXT,
        race INTEGER,
        class INTEGER,
        gender INTEGER,
        level INTEGER,
        xp INTEGER,
        health INTEGER,
        power1 INTEGER,
        money INTEGER,
        skin INTEGER,
        face INTEGER,
        hairStyle INTEGER,
        hairColor INTEGER,
        facialStyle INTEGER,
        bankSlots INTEGER,
        exploredZones TEXT,
        equipmentCache TEXT,
        ammoId INTEGER,
        arenapoints INTEGER,
        totalHonorPoints INTEGER,
        totalKills INTEGER,
        creation_date TEXT,
        map INTEGER,
        zone INTEGER
    );
	"
    Invoke-SQLiteQuery -Database $DBFilePath -Query $createTableQuery
}
########################################


########################################
try {
	# Start logging
	$CurrentDate = Get-Date -Format "yyyyMMdd_HHmmss"
	Start-Transcript -Path "./logs/AutoBackupScript_$($CurrentDate).log" -Append
	
	# Open database connections
	Open-MySqlConnection -Server $SourceServerName -Port $SourcePort -Database $SourceDatabaseAuth -Credential (New-Object System.Management.Automation.PSCredential($SourceUsername, (ConvertTo-SecureString $SourcePassword -AsPlainText -Force))) -ConnectionName "AuthConn"
	Open-MySqlConnection -Server $SourceServerName -Port $SourcePort -Database $SourceDatabaseCharacters -Credential (New-Object System.Management.Automation.PSCredential($SourceUsername, (ConvertTo-SecureString $SourcePassword -AsPlainText -Force))) -ConnectionName "CharConn"
	Open-MySqlConnection -Server $SourceServerName -Port $SourcePort -Database $SourceDatabaseWorld -Credential (New-Object System.Management.Automation.PSCredential($SourceUsername, (ConvertTo-SecureString $SourcePassword -AsPlainText -Force))) -ConnectionName "WorldConn"
		
	Write-Host "(Press CTRL + C to stop the script)" -ForegroundColor Yellow
	$exitScript = $false
	while (-not $exitScript) {
			
		foreach ($Character in $CharacterList) {
			# Check if the row already exists in the database
			$Query = "SELECT COUNT(*) as count FROM characters WHERE name LIKE '%$Character%';"
			$ValueColumn = "count"
			$ConnectionName = "CharConn"
			$result = Check-Value-in-DB -Query $Query -ValueColumn $ValueColumn -ConnectionName $ConnectionName
			
			if ($result) {
				$CharacterData = Invoke-SqlQuery -ConnectionName "CharConn" -Query "SELECT guid, account, name, race, class, gender, level, xp, health, power1, money, skin, face, hairStyle, hairColor, facialStyle, bankSlots, equipmentCache, ammoId, arenapoints, totalHonorPoints, totalKills, creation_date, map, zone FROM characters WHERE name = @Character" -Parameters @{ Character = $Character }

				$CharacterId = $CharacterData.guid
				$CharacterAccountId = $CharacterData.account
				$CharacterName = $CharacterData.name
				
				$CharacterRace = GetCharacterRaceString -Race $CharacterData.race
				$CharacterClass = GetCharacterClassString -Class $CharacterData.class
				$CharacterGender = GetCharacterGenderString -Gender $CharacterData.gender
				
				$CharacterLevel = $CharacterData.level
				$CharacterHonor = $CharacterData.totalHonorPoints
				$CharacterCreationDate = $CharacterData.creation_date
				#Convert creation date to day/month/year
				$CharacterCreationDate = (Get-Date $CharacterCreationDate).ToString("dd/MM/yyyy HH:mm:ss")
	
				$CharacterMoney = $CharacterData.money
				$CharacterMoneyConverted = ConvertToGoldSilverCopper -MoneyAmount $CharacterData.money
				
				$CharacterXP = $CharacterData.xp
				$CharacterHealth = $CharacterData.health
				$CharacterSkin = $CharacterData.skin
				$CharacterFace = $CharacterData.face
				$CharacterHairStyle = $CharacterData.hairStyle
				$CharacterHairColor = $CharacterData.hairColor
				$CharacterFacialStyle = $CharacterData.facialStyle
				$CharacterBankSlots = $CharacterData.bankSlots
				$CharacterEquipmentCache = $CharacterData.equipmentCache
				$CharacterAmmoId = $CharacterData.ammoId
				$CharacterArenapoints = $CharacterData.arenapoints
				$CharacterTotalKills = $CharacterData.totalKills
				$CharacterCurMap = $CharacterData.map
				$CharacterCurZone = $CharacterData.zone
				$CharacterMana = $CharacterData.power1
				
				
				$AccountName = Invoke-SqlQuery -ConnectionName "AuthConn" -Query "SELECT username FROM account WHERE id = @CharacterAccountId" -Parameters @{ CharacterAccountId = $CharacterAccountId }
 
				#check sqlite database for character 
				#if not in database create row for it and back it up
				# Step 2: Check if character exists in SQLite
				$temp_query = "SELECT * FROM Characters 
				WHERE guid = @Guid AND 
					accountName = @AccountName AND 
					race = @Race AND 
					class = @Class AND 
					gender = @Gender AND 
					level = @Level AND 
					xp = @XP AND 
					health = @Health AND 
					power1 = @Mana AND 
					money = @Money AND 
					skin = @Skin AND 
					face = @Face AND 
					hairStyle = @HairStyle AND 
					hairColor = @HairColor AND 
					facialStyle = @FacialStyle AND 
					bankSlots = @BankSlots AND 
					equipmentCache = @EquipmentCache AND 
					ammoId = @AmmoId AND 
					arenapoints = @ArenaPoints AND 
					totalHonorPoints = @TotalHonorPoints AND 
					totalKills = @TotalKills AND 
					creation_date = @CreationDate AND
					map = @Map AND
					zone = @Zone;
				"
				
				$result = Invoke-SQLiteQuery -DataSource $DBFilePath -Query $temp_query -SqlParameters @{
					Guid = $CharacterData.guid
					AccountName = $AccountName.username
					Race = $CharacterData.race
					Class = $CharacterData.class
					Gender = $CharacterData.gender
					Level = $CharacterData.level
					XP = $CharacterData.xp
					Health = $CharacterData.health
					Money = $CharacterData.money
					Skin = $CharacterData.skin
					Face = $CharacterData.face
					HairStyle = $CharacterData.hairStyle
					HairColor = $CharacterData.hairColor
					FacialStyle = $CharacterData.facialStyle
					BankSlots = $CharacterData.bankSlots
					EquipmentCache = $CharacterData.equipmentCache
					AmmoId = $CharacterData.ammoId
					ArenaPoints = $CharacterData.arenapoints
					TotalHonorPoints = $CharacterData.totalHonorPoints
					TotalKills = $CharacterData.totalKills
					CreationDate = $CharacterData.creation_date
					Map = $CharacterData.map
					Zone = $CharacterData.zone
					Mana = $CharacterData.power1
				}

				#if already exists, skip
				if ($result) {
					Write-Host "No changes detected in character $CharacterName data. Skipping..." -ForegroundColor Yellow
					
				} else {
					# Step 3: Delete any rows with the same name
					$delete_query = "DELETE FROM Characters WHERE name = @Character;"
					Invoke-SQLiteQuery -DataSource $DBFilePath -Query $delete_query -SqlParameters @{ Character = $CharacterName }
				
					# Step 4: Insert new character data into SQLite
					$insert_query = "INSERT INTO Characters (guid, accountName, name, race, class, gender, level, xp, health, power1, money, skin, face, hairStyle, hairColor, facialStyle, bankSlots, exploredZones, equipmentCache, ammoId, arenapoints, totalHonorPoints, totalKills, creation_date, map, zone) VALUES (@Guid, @accountName, @Name, @Race, @Class, @Gender, @Level, @Xp, @Health, @Mana, @Money, @Skin, @Face, @HairStyle, @HairColor, @FacialStyle, @BankSlots, @ExploredZones, @EquipmentCache, @AmmoId, @ArenaPoints, @TotalHonorPoints, @TotalKills, @CreationDate, @Map, @Zone);"
					Invoke-SQLiteQuery -DataSource $DBFilePath -Query $insert_query -SqlParameters @{
						Guid = $CharacterData.guid
						accountName = $AccountName.username
						Name = $CharacterData.name
						Race = $CharacterData.race
						Class = $CharacterData.class
						Gender = $CharacterData.gender
						Level = $CharacterData.level
						Xp = $CharacterData.xp
						Health = $CharacterData.health
						Mana = $CharacterData.power1
						Money = $CharacterData.money
						Skin = $CharacterData.skin
						Face = $CharacterData.face
						HairStyle = $CharacterData.hairStyle
						HairColor = $CharacterData.hairColor
						FacialStyle = $CharacterData.facialStyle
						BankSlots = $CharacterData.bankSlots
						ExploredZones = $CharacterData.exploredZones
						EquipmentCache = $CharacterData.equipmentCache
						AmmoId = $CharacterData.ammoId
						ArenaPoints = $CharacterData.arenapoints
						TotalHonorPoints = $CharacterData.totalHonorPoints
						TotalKills = $CharacterData.totalKills
						CreationDate = $CharacterData.creation_date
						Map = $CharacterData.map
						Zone = $CharacterData.zone
					}
					# Write-Host "Character data inserted into SQLite."

					
					$CurrentDate = Get-Date -Format "yyyyMMdd_HHmmss"
					
					$CharacterMoney = $CharacterData.money
					$CharacterXP = $CharacterData.xp
					$CharacterHonor = $CharacterData.totalHonorPoints
					
					
########################################
					$BackupDirFilename = "$CharacterName ($CurrentDate) - $CharacterRace $CharacterClass $CharacterGender LV$CharacterLevel"
					$AccountNameString = $AccountName.username
					$backupDirFull = "$CharacterBackupDir\$AccountNameString\$BackupDirFilename"
					
######################################## Create character_info txt file
					$CurCharMoneyConverted = ConvertToGoldSilverCopper -MoneyAmount $CharacterData.money
					
					if (-not (Test-Path $backupDirFull)) {
						New-Item -Path $backupDirFull -ItemType Directory | Out-Null
					}
					
########################################
					# Using splatting to avoid line continuation issues
					$characterInfoParams = @{
						backupDirFull = $backupDirFull
						CharacterId = $CharacterData.guid
						CharacterAccountId = $CharacterAccountId
						CharacterAccountName = $AccountNameString
						CharacterCreationDate = $CharacterData.creation_date
						CharacterName = $CharacterData.name
						CharacterRaceString = $CharacterRace
						CharacterClassString = $CharacterClass
						CharacterGenderString = $CharacterGender
						CharacterLevel = $CharacterData.level
						CharacterHonor = $CharacterData.totalHonorPoints
						CharacterMoneyConverted = $CurCharMoneyConverted
						CharacterXP = $CharacterData.xp
						CharacterHealth = $CharacterData.health
						CharacterMana = $CharacterData.power1
						CharacterSkin = $CharacterData.skin
						CharacterFace = $CharacterData.face
						CharacterHairStyle = $CharacterData.hairStyle
						CharacterHairColor = $CharacterData.hairColor
						CharacterFacialStyle = $CharacterData.facialStyle
						CharacterBankSlots = $CharacterData.bankSlots
						CharacterArenapoints = $CharacterData.arenapoints
						CharacterTotalKills = $CharacterData.totalKills
						CharacterEquipmentCache = $CharacterData.equipmentCache
						CharacterAmmoId = $CharacterData.ammoId
						CharacterCurMap = $CharacterData.map
						CharacterCurZone = $CharacterData.zone
					}
					CreateCharacterInfoFile @characterInfoParams
#############################################################
					Backup-Character -characterId $CharacterData.guid -characterName $CharacterData.name -accountID $id -BackupDir $backupDirFull
					
					#7zip and delete folder
					if ($7zipCompression) {
						# Write-Host "Backup directory: $backupDirFull" -ForegroundColor Yellow
						if (Test-Path $backupDirFull) {
							$BackupFilePath = Join-Path -Path "$CharacterBackupDir\$AccountNameString" -ChildPath $BackupDirFilename
							# Write-Host "Creating archive..." -ForegroundColor Yellow
							7z a -t7z "$BackupFilePath" $backupDirFull > NUL
							Write-Host "Created archive for character files ($BackupDirFilename)." -ForegroundColor Green
							
							#delete folder
							Remove-Item -LiteralPath $backupDirFull -Force -Recurse
						}
						
					}
					Write-Host "Character $CharacterName backed up." -ForegroundColor Green
				}
########################################
			} else {
				Write-Host "Character $Character does not exist in database. Skipping..." -ForegroundColor Red
			}
		}
		
		Write-Host "`nWaiting for $BackupDelay seconds." -ForegroundColor Yellow
		# Start-Sleep -Seconds $BackupDelay
		for ($i = 1; $i -le $BackupDelay; $i++) {
			Write-Host -NoNewline "."
			Start-Sleep -Seconds 1
		}
	}
########################################
########################################
} catch {
    Write-Host ("Error: An unexpected error occurred in {0} (function {1}, script {2}, line {3}): {4}" -f `
        $_.InvocationInfo.MyCommand.Name,      # Function or command name
        $_.InvocationInfo.FunctionName,        # Function name (if inside a function)
        $_.InvocationInfo.ScriptName,          # Script file name
        $_.InvocationInfo.ScriptLineNumber,    # Line number
        $_.Exception.Message                   # Exception message
    ) -ForegroundColor Red
} finally {
	# Close all connections
	Close-SqlConnection -ConnectionName "AuthConn"
	Close-SqlConnection -ConnectionName "CharConn"
	Close-SqlConnection -ConnectionName "WorldConn"
	
	Stop-Transcript
    [console]::beep()
    pause
	# Write-Output "Transcript stopped"
}
########################################
