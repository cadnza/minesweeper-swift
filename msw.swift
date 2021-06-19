import Swift

func getInput() -> String {
	let promptChar: String = ">"
	print(promptChar, terminator: " ")
	let final: String = readLine()!
	return final
}

func skipLine() {
	print("")
}

class MSW {

	private var started: Bool = false

	private var size: [Int]
	private var nMine: Int

	private let kMine: Int = 9

	private let sMine: String = "x"

	private let sCover: String = "."
	private let sEmpty: String = " "
	private let sFlag: String = "!"
	private let sQuestion: String = "?"

	private let flagsLeftMessage: String = "Flags left: "

	private let letters: [String] = [
		"A","B","C","D","E","F","G",
		"H","I","J","K","L","M","N",
		"O","P","Q","R","S","T","U",
		"V","W","X","Y","Z"
	]
	private let integers: [String] = Array(0...9).map{String($0)}

	private var hidden: [Int]? = nil
	private lazy var visible: [String] = [String](repeating: self.sCover, count: self.size[0]*self.size[1])

	private struct Difficulty {
		let nRow: Int
		let nCol: Int
		let nMine: Int
	}

	init() {
		// Set difficulty levels
		let levels: [Difficulty] = [
			Difficulty(nRow: 10, nCol: 10, nMine: 15),
			Difficulty(nRow: 15, nCol: 15, nMine: 33),
			Difficulty(nRow: 20, nCol: 20, nMine: 60),
			Difficulty(nRow: 20, nCol: 30, nMine: 90)
		]
		var levelNames: [String] = [
			"Easy",
			"Medium",
			"Hard",
			"Expert"
		]
		// Get difficulty level from user
		print("Difficulty?:")
		skipLine()
		for i in 0..<levelNames.count {
			levelNames[i] = "\(i+1). \(levelNames[i])"
			print(levelNames[i])
		}
		skipLine()
		var difficultyIndex: String = getInput()
		while !((1...levels.count).map{String($0)}).contains(difficultyIndex){
			skipLine()
			print("A number 1 to \(levels.count), please:")
			difficultyIndex = getInput()
		}
		let chosenDifficultyIndex: Int = Int(difficultyIndex)!-1;
		let chosenDifficulty: Difficulty = levels[chosenDifficultyIndex]
		// Set parameters
		self.size = [chosenDifficulty.nRow, chosenDifficulty.nCol]
		self.nMine = chosenDifficulty.nMine
		// Show intro
		skipLine()
		print("Let's play Minesweeper!")
		skipLine()
		print("Type a reference to select a square,")
		print("e.g. B5 or c12.")
		skipLine()
		print("To flag a square as a possible mine,")
		print("put a \(self.sFlag) before its reference, e.g.")
		print("\(self.sFlag)B5 or \(self.sFlag)c12.")
		skipLine()
		print("If you're not sure about a square,")
		print("mark it with a \(self.sQuestion), e.g. \(self.sQuestion)B5 or \(self.sQuestion)c12.")
		skipLine()
		print("And \(self.sCover) resets a previously \(self.sFlag)ed or \(self.sQuestion)ed")
		print("square, e.g. \(self.sCover)B5 or \(self.sCover)c12.")
		skipLine()
		print("That's all, good luck!")
		// Go
		self.play()
	}

	private func play() {
		// Set playing status
		var stillPlaying: Bool = true
		// Start loop
		while(stillPlaying) {
			// Show grid
			self.showVisible()
			// Get input
			let userInput: String = getInput();
			// Interpret input
			do {
				try self.interpretInput(input: userInput)
			} catch inputError.badCharacter {
				skipLine()
				print("Remember:")
				print("\(self.sFlag) - Flag")
				print("\(self.sQuestion) - Question")
				print("\(self.sCover) - Reset")
			} catch inputError.outOfOrder {
				skipLine()
				print("You want column then row, e.g. B5 or c12.")
			} catch inputError.noColumn {
				skipLine()
				print("You'll need a column letter before your row number.")
			} catch inputError.noRow {
				skipLine()
				print("You'll need a row number after your column letter.")
			} catch inputError.badColRef {
				skipLine()
				print("It doesn't look like that's a column.")
			} catch inputError.outOfBounds {
				skipLine()
				print("It doesn't look like we have that square on the board.")
			} catch inputError.noMoreFlags {
				skipLine()
				print("You're out of flags!")
				print("You can unflag squares with \(self.sCover), e.g. \(self.sCover)B5 or \(self.sCover)c12.")
			} catch inputError.hardExit {
				skipLine()
				print("👷")
				skipLine()
				stillPlaying = false
			} catch {
				skipLine()
				print("Hmmm...")
			}
			// Only proceed if game is started
			if !self.started {
				continue
			}
			// Check for victory and end game if so
			let isVictory: Bool = checkForVictory()
			if isVictory {
				stillPlaying = false
				for i in 0..<self.visible.count {
					if self.hidden![i] != self.kMine {
						self.select(idx: i)
					}
				}
				showVisible()
				skipLine()
				print("😎")
				skipLine()
			}
			// Check for loss and end game if so
			let isLoss: Bool = self.visible.contains(self.sMine)
			if isLoss {
				stillPlaying = false
				for i in 0..<self.visible.count {
					if self.hidden![i] == self.kMine {
						self.select(idx: i)
					}
				}
				showVisible()
				skipLine()
				print("😣")
				skipLine()
			}
		}
	}

	private enum inputError: Error {
		case noColumn
		case noRow
		case badCharacter
		case badColRef
		case outOfOrder
		case outOfBounds
		case noMoreFlags
		case hardExit
	}

	private func interpretInput(input: String) throws {
		// Uppercase input
		let x: String = input.uppercased()
		if ["QUIT","Q","EXIT"].contains(x) {
			throw inputError.hardExit
		}
		// Set control variables
		var cnChars: [String] = []
		var rwChars: [String] = []
		var uniqueLetters: [String] = []
		var awaitingSp: Bool = true
		var awaitingCn: Bool = true
		var doFlag: Bool = false
		var doQuestion: Bool = false
		var doCover: Bool = false
		// Start reading loop
		for i in 0..<x.count {
			// Set current value
			let currVal = String(x[x.index(x.startIndex, offsetBy: i)])
			// Ignore whitespace
			if ["\t"," "].contains(currVal) {
				continue
			}
			// Error on unexpected characters
			if !(self.letters + self.integers + [self.sFlag, self.sQuestion, self.sCover]).contains(currVal) {
				throw inputError.badCharacter
			}
			if [self.sFlag, self.sQuestion, self.sCover].contains(currVal) && !awaitingSp {
				throw inputError.outOfOrder
			}
			// Get flags
			if awaitingSp {
				if currVal == self.sFlag {
					doFlag = true
					awaitingSp = false
				}
				if currVal == self.sQuestion {
					doQuestion = true
					awaitingSp = false
				}
				if currVal == self.sCover {
					doCover = true
					awaitingSp = false
				}
			}
			// Get column characters
			if self.letters.contains(currVal) {
				if awaitingCn {
					cnChars.append(currVal)
				} else {
					throw inputError.outOfOrder
				}
			}
			// Get row characters
			if self.integers.contains(currVal) {
				awaitingCn = false
				rwChars.append(currVal)
			}
		}
		// Check existence of column
		if cnChars.count == 0 {
			throw inputError.noColumn
		}
		// Check existence of row
		if rwChars.count == 0 {
			throw inputError.noRow
		}
		// Make sure all letters in column referece are the same
		for x in cnChars {
			if !uniqueLetters.contains(x) {
				uniqueLetters.append(x)
			}
		}
		if uniqueLetters.count > 1 {
			throw inputError.badColRef
		}
		// Get column index
		let cnRef: String = cnChars.joined(separator: "")
		let focusLetter: String = cnChars[0]
		let cnMult: Int = cnRef.count - 1
		let cnIndex: Int = letters.firstIndex(of: focusLetter)! + letters.count * cnMult + 1
		// Get row index
		let rwIndex: Int = Int(rwChars.joined(separator: ""))! - 1
		// Validate bounds
		if rwIndex >= self.size[0] || cnIndex > self.size[1] || rwIndex < 0 || cnIndex < 0 {
			throw inputError.outOfBounds
		}
		// Get single index from row and column indices
		let idx: Int = rwCnToIdx(rw: rwIndex, cn: cnIndex)
		// Abort if already clicked
		if ![self.sFlag, self.sQuestion, self.sCover].contains(self.visible[idx]) {
			return
		}
		// Flag, question, or cover if appropriate
		if doFlag {
			let nFlagsLeft: Int = self.countFlagsLeft()
			if nFlagsLeft > 0 {
				self.visible[idx] = self.sFlag
			} else {
				throw inputError.noMoreFlags
			}
		}
		if doQuestion {
			self.visible[idx] = self.sQuestion
		}
		if doCover {
			self.visible[idx] = self.sCover
		}
		// Select if not flagging or questioning
		if !doFlag && !doQuestion && !doCover {
			self.select(idx: idx)
		}
		// Return
		return
	}

	private func checkForVictory() -> Bool {
		for i in 0..<self.visible.count {
			if self.hidden![i] == self.kMine && self.visible[i] != self.sFlag {
				return false
			}
		}
		return true
	}

	private func select(idx: Int) {
		// Initialize hidden grid on first select and start game
		if self.hidden == nil {
			self.hidden = self.getHiddenGrid(exclude: idx)
			self.started = true
		}
		// Uncover square at index
		self.visible[idx] = self.hidden![idx] == self.kMine ? self.sMine : String(self.hidden![idx])
		// Recursively uncover adjacent squares if 0
		if self.hidden![idx] == 0 {
			let adjs: [Int] = self.getAdjSquares(grid: self.hidden!, idx: idx)
			for a in adjs {
				if [self.sCover, self.sFlag, self.sQuestion].contains(self.visible[a]) {
					self.select(idx: a)
				}
			}
		}
	}

	private func showVisible() {
		skipLine()
		let nFlagsLeft: Int = self.countFlagsLeft()
		print("\(self.flagsLeftMessage)\(nFlagsLeft)")
		let visibleCosmetic: [String] = self.visible.map{
			if $0 == "0" {
				return self.sEmpty
			} else {
				return $0
			}
		}
		self.reportGrid(visibleCosmetic)
	}

	private func reportGrid(_ grid: [String]) {
		var gridNew: [String] = [" "]
		for i in 1...self.size[1] {
			let idx: Int = i - 1
			let focusLetter: String = self.letters[idx % letters.count]
			let nRepeats: Int = ceiling(i, letters.count)
			let cnLabel = [String](repeating: focusLetter, count: nRepeats).joined(separator: "")
			gridNew.append(cnLabel)
		}
		for i in 0..<grid.count {
			if (i + 1) % self.size[1] == 1 {
				gridNew.append(String(i / self.size[1] + 1))
			}
			gridNew.append(grid[i])
		}
		var final: String = ""
		let space: Int = gridNew.map{$0.count}.max()! + 1
		func addToFinal(_ x: String) {
			var xNew: String = x
			let spaceRemaining: Int = space - xNew.count
			for _ in 1...(spaceRemaining) {
				xNew = "\(xNew) "
			}
			final = "\(final)\(xNew)"
		}
		for i in 0..<gridNew.count {
			addToFinal(gridNew[i])
			if (i + 1) % (self.size[1] + 1) == 0 {
				final = "\(final)\n"
			}
		}
		print(final)
	}

	private func getHiddenGrid(exclude: Int) -> [Int] {
		// Initialize hidden grid
		var hidden: [Int] = [Int](repeating: 0, count: self.size[0]*self.size[1])
		// Initialize placement options, excluding excluded index
		var placementOpts: [Int] = [Int](0..<hidden.count).filter{$0 != exclude}
		// Shuffle placement options
		for i in (1..<placementOpts.count).reversed() {
			let j: Int = Int.random(in: 0...i)
			let temp: Int = placementOpts[i]
			placementOpts[i] = placementOpts[j]
			placementOpts[j] = temp
		}
		// Place mines
		let minePlacements = placementOpts[0..<nMine]
		for i in minePlacements{
			hidden[i] = self.kMine
		}
		// Count mines adjacent to each square
		for i in 0..<hidden.count {
			if hidden[i] != kMine {
				let adjs: [Int] = self.getAdjSquares(grid: hidden, idx: i)
				let ct: Int = adjs.filter{hidden[$0]==self.kMine}.count
				hidden[i] = ct
			}
		}
		// Return
		return hidden
	}

	private func getAdjSquares(grid: [Int], idx: Int) -> [Int] {
		// Initialize array for adjacent squares
		var final: [Int] = []
		// Convert to 1 basis for simplicity
		let idx1: Int = idx + 1
		// Check edge orientation
		let isUpper: Bool = idx1 <= self.size[1]
		let isRight: Bool = idx1 % self.size[1] == 0
		let isLower: Bool = idx1 > (self.size[0] - 1) * self.size[1]
		let isLeftt: Bool = idx1 % self.size[1] == 1
		// Get upper left
		if !isUpper && !isLeftt {
			final.append(idx1 - self.size[1] - 1)
		}
		// Get upper
		if !isUpper {
			final.append(idx1 - self.size[1])
		}
		// Get upper right
		if !isUpper && !isRight {
			final.append(idx1 - self.size[1] + 1)
		}
		// Get left
		if !isLeftt {
			final.append(idx1 - 1)
		}
		// Get right
		if !isRight {
			final.append(idx1 + 1)
		}
		// Get lower left
		if !isLower && !isLeftt {
			final.append(idx1 + self.size[1] - 1)
		}
		// Get lower
		if !isLower {
			final.append(idx1 + self.size[1])
		}
		// Get lower right
		if !isLower && !isRight {
			final.append(idx1 + self.size[1] + 1)
		}
		// Convert back to 0 basis
		final = final.map{$0 - 1}
		// Return
		return final
	}

	private func countFlagsLeft() -> Int {
		let final: Int = self.nMine - self.visible.filter{$0 == self.sFlag}.count
		return final
	}

	private func rwCnToIdx(rw: Int, cn: Int) -> Int {
		let final: Int = rw * self.size[1] + cn - 1
		return final
	}

	private func idxToRwCn(idx: Int) -> [Int] {
		let idx1: Int = idx + 1
		let cn: Int = idx1 % self.size[1]
		let rw: Int = (idx1 - cn) / self.size[1]
		let final: [Int] = [rw,cn]
		return final
	}

	private func ceiling(_ dividend: Int, _ divisor: Int) -> Int {
		let final: Int = Int((dividend / divisor) + ((dividend % divisor) != 0 ? 1 : 0))
		return final
	}

}

let ms = MSW()
