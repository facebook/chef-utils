# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2
require_relative '../../between-meals/changes/change'
require_relative '../../between-meals/changes/cookbook'
require_relative '../../between-meals/changeset'
require 'logger'

describe BetweenMeals::Changes::Cookbook do
  let(:logger) do
    Logger.new('/dev/null')
  end
  let(:cookbook_dirs) do
    ['cookbooks/one', 'cookbooks/two']
  end

  FIXTURES = [
    {
      :name => 'empty filelists',
      :files => [],
      :result => [],
    },
    {
      :name => 'modifying of a cookbook',
      :files => [
        {
          :status => :modified,
          :path => 'cookbooks/two/cb_one/recipes/test.rb'
        },
        {
          :status => :modified,
          :path => 'cookbooks/two/cb_one/metadata.rb'
        },
      ],
      :result => [
        ['cb_one', :modified],
      ],
    },
    {
      :name => 'a mix of in-place modifications and deletes',
      :files => [
        {
          :status => :modified,
          :path => 'cookbooks/one/cb_one/recipes/test.rb'
        },
        {
          :status => :deleted,
          :path => 'cookbooks/one/cb_one/recipes/test2.rb'
        },
        {
          :status => :modified,
          :path => 'cookbooks/one/cb_one/recipes/test3.rb'
        },
      ],
      :result => [
        ['cb_one', :modified],
      ],
    },
    {
      :name => 'removing metadata.rb - invalid cookbook, delete it',
      :files => [
        {
          :status => :modified,
          :path => 'cookbooks/one/cb_one/recipes/test.rb'
        },
        {
          :status => :deleted,
          :path => 'cookbooks/one/cb_one/metadata.rb'
        },
      ],
      :result => [
        ['cb_one', :deleted],
      ],
    },
    {
      :name => 'changing cookbook location',
      :files => [
        {
          :status => :deleted,
          :path => 'cookbooks/one/cb_one/recipes/test.rb'
        },
        {
          :status => :deleted,
          :path => 'cookbooks/one/cb_one/metadata.rb'
        },
        {
          :status => :modified,
          :path => 'cookbooks/two/cb_one/recipes/test.rb'
        },
        {
          :status => :modified,
          :path => 'cookbooks/two/cb_one/recipes/test2.rb'
        },
        {
          :status => :modified,
          :path => 'cookbooks/two/cb_one/metadata.rb'
        },
      ],
      :result => [
        ['cb_one', :deleted],
        ['cb_one', :modified],
      ],
    },
    {
      :name => 'modifying metadata only',
      :files => [
        {
          :status => :modified,
          :path => 'cookbooks/two/cb_one/metadata.rb'
        },
      ],
      :result => [
        ['cb_one', :modified],
      ],
    },
    {
      :name => 'modifying README only',
      :files => [
        {
          :status => :modified,
          :path => 'cookbooks/two/cb_one/README.md'
        },
      ],
      :result => [
        ['cb_one', :modified],
      ],
    },
    {
      :name => 'modifying recipe only',
      :files => [
        {
          :status => :modified,
          :path => 'cookbooks/two/cb_one/recipe/default.rb'
        },
      ],
      :result => [
        ['cb_one', :modified],
      ],
    },
    {
      :name => 'skipping non-cookbook files',
      :files => [
        {
          :status => :modified,
          :path => 'cookbooks/two/OWNERS'
        },
        {
          :status => :modified,
          :path => 'cookbooks/OWNERS'
        },
        {
          :status => :modified,
          :path => 'OWNERS'
        },
      ],
      :result => [
      ],
    },
  ]

  FIXTURES.each do |fixture|
    it "should handle #{fixture[:name]}" do
      BetweenMeals::Changes::Cookbook.find(
        fixture[:files],
        cookbook_dirs,
        logger
      ).map do |cb|
        [cb.name, cb.status]
      end.
      should eq(fixture[:result])
    end
  end

end
