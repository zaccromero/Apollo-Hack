"use strict";
// Fictional website teaching examples, separate from the native app and live markets.
const APOLLO_EXAMPLES = Object.freeze({
 stock: {
  symbol:"C", kind:"Stock example", name:"Example company", price:100, multiplier:1, quantity:10, unit:"shares", quoteLabel:"Illustrative share price",
  description:"A business you recognize. A price worth questioning.",
  question:"You like the company. What would make the investment worth its price?",
  discoverTitle:"Start with curiosity, not certainty.",
  discover:"Recognizing a business is different from understanding an investment. Before deciding, ask what the price assumes about its future.",
  understandTitle:"Look for the case—and the countercase.",
  points:["The case: imagine revenue grew 8% in a fictional year.","The countercase: costs grew 12%; sales growth alone would not establish stronger profit.","The unanswered question: what price fairly reflects the business, its costs and future uncertainty?"],
  limit:"Invented teaching figures, not financial statements or a recommendation. A real assessment needs dated, sourced information.",
  risk:"A share price can fall. Liking the product does not protect the value of an investment."
 },
 etf: {
  symbol:"B", kind:"ETF example", name:"Sample market basket", price:50, multiplier:1, quantity:10, unit:"shares", quoteLabel:"Illustrative fund share price",
  description:"One fund. More than one source of risk.",
  question:"What’s inside the basket—and how much depends on the same few companies?",
  discoverTitle:"A basket is a beginning, not an answer.",
  discover:"An ETF can hold many investments. Its name alone doesn’t tell you how concentrated those holdings are, or what the fund costs.",
  understandTitle:"Look through the label.",
  points:["The holdings: this fictional basket contains 20 companies.","The concentration: its three largest holdings account for 45% of the basket.","The risk: a fall in those three can meaningfully affect the whole basket, despite its 20 names."],
  limit:"Invented holdings and weights for this lesson. Fees, sectors and actual holdings would also matter; this is not a real ETF.",
  risk:"A basket can still lose value. Diversification depends on the holdings, not only the number of names."
 },
 option: {
  symbol:"×", kind:"Options example", name:"Sample call contract", price:5, multiplier:100, quantity:1, unit:"contracts", quoteLabel:"Illustrative quoted premium",
  description:"A small quote can mean a larger commitment.",
  question:"A $5 premium with a 100-unit multiplier: what does one contract cost?",
  discoverTitle:"Read the whole contract.",
  discover:"The quoted premium isn’t the total cost. For this example, each contract uses a 100-unit multiplier: $5 × 100 = $500 before fees.",
  understandTitle:"Price is only part of the story.",
  points:["The multiplier: one contract in this example represents 100 units.","The terms: strike price and expiration affect what the contract means.","The downside: a long option can lose the entire premium paid."],
  limit:"Illustrative long-call premium only. No underlying security, strike, expiration, payoff forecast or live contract is supplied.",
  risk:"For a long option, the entire premium can be lost. This simplified cost example excludes fees."
 }
});
