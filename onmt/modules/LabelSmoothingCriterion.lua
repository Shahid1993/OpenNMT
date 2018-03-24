--[[
  Implement Label smoothing criterion as defined in Szegedy, 2015 (https://arxiv.org/pdf/1512.00567.pdf)
--]]

local LabelSmoothingCriterion, parent = torch.class('nn.LabelSmoothingCriterion', 'nn.DistKLDivCriterion')

-- initialization requires value for epsilon
-- if provided a prior vocab distribution define probability accordingly otherwise, just uniform
function LabelSmoothingCriterion:__init(size, epsilon, vocab_distribution)
  parent.__init(self)

  self.epsilon = epsilon
  self.u = torch.Tensor(1, size)
  self.weights = torch.Tensor(1, size)
  self.size = size
  self.confidence = torch.Tensor{1-epsilon}
  if vocab_distribution then
    self.vocab_distribution = vocab_distribution
    self.vocab_distribution[onmt.Constants.PAD] = 0
  else
    self.org_size = size
  end

  self:updateVocab()
end

function LabelSmoothingCriterion:updateVocab(vocab_index)
  if self.vocab_distribution then
    if not vocab_index then
      self.weights:resize(1, self.vocab_distribution:size())
      self.weights:copy(self.vocab_distribution)
    else
      self.weights:resize(1, vocab_index:size())
      self.weights:copy(self.vocab_distribution:index(1, vocab_index))
    end
    self.size = self.weights:sum(1)[1]
    self.weights = self.weights * self.epsilon / self.size
  else
    self.size = vocab_index and vocab_index:size() or self.org_size
    self.weights:fill(self.epsilon / (self.size - 1))
  end
end


function LabelSmoothingCriterion:updateOutput(input, target)
  self.weights:expand(1, input:size(0))
  self.u:resize(input):copy(self.weights)
  self.u:indexAdd(2, target, self.confidence:expand(1, input:size(0)))
  return parent:updateOutput(self, input, self.one_hot)
end

function LabelSmoothingCriterion:updateGradInput(input)
  return parent:updateGradInput(self, input, self.one_hot)
end
