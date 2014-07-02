# Encoding: utf-8
require 'spec_helper'

describe 'syntax check' do
  it 'should not raise errors' do
    expect(`rubocop`).to include('no offenses detected')
  end
end
