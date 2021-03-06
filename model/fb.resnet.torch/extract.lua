--
--  Copyright (c) 2016, Facebook, Inc.
--  All rights reserved.
--
--  This source code is licensed under the BSD-style license found in the
--  LICENSE file in the root directory of this source tree. An additional grant
--  of patent rights can be found in the PATENTS file in the same directory.
--
--  extracts features from an image using a trained model
--

require 'torch'
require 'paths'

if #arg < 2 then
   io.stderr:write('Usage: th extract-features.lua [MODEL] [FILE]...\n')
   os.exit(1)
end
for _, f in ipairs(arg) do
   if not paths.filep(f) then
      io.stderr:write('file not found: ' .. f .. '\n')
      os.exit(1)
   end
end

require 'cudnn'
require 'cunn'
require 'image'
local t = require '../datasets/transforms'

-- Load the model
local model = torch.load(arg[1])

-- Remove the fully connected layer
assert(torch.type(model:get(#model.modules)) == 'nn.Linear')
model:remove(#model.modules)

-- The model was trained with this input normalization
local meanstd = {
   mean = { 0.485, 0.456, 0.406 },
   std = { 0.229, 0.224, 0.225 },
}

local transform = t.Compose{
   t.Scale(256),
   t.ColorNormalize(meanstd),
   t.CenterCrop(224),
}

local features

-- see if the file exists
function file_exists(file)
  local f = io.open(file, "rb")
  if f then f:close() end
  return f ~= nil
end

-- get all lines from a file, returns an empty 
-- list/table if the file does not exist
function lines_from(file)
  if not file_exists(file) then return {} end
  lines = {}
  for line in io.lines(file) do 
    lines[#lines + 1] = line
  end
  return lines
end

local lines = lines_from('/home/dima/yelp/test_list')

-- print all line numbers and their contents
Count = 0
for Index, Value in pairs( lines ) do
  Count = Count + 1
end
print (Count)
for i,v in pairs(lines) do
    print (i, v)
   -- load the image as a RGB float tensor with values 0..1
   local img = image.load(v, 3, 'float')

   -- Scale, normalize, and crop the image
   img = transform(img)

   -- View as mini-batch of size 1
   img = img:view(1, table.unpack(img:size():totable()))

   -- Get the output of the layer before the (removed) fully connected layer
   local output = model:forward(img:cuda()):squeeze(1)

   if not features then
      features = torch.FloatTensor(Count, output:size(1)):zero()
   end

   features[i]:copy(output)
end

local fwrite = function(tensor, file)
  if not tensor then return false end
  local n = tensor:nElement()
  local s = tensor:storage()
  return assert(file:writeFloat(s) == n)
end

-- torch.save('train_features.t7', features)
local file = torch.DiskFile("test_features101.bin", "w"):binary()
fwrite(features, file)
-- print (features)
-- features = torch.Double('bb')
        
