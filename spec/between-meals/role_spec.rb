# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2
require_relative '../../between-meals/changes/change'
require_relative '../../between-meals/changes/role'
require 'logger'

describe BetweenMeals::Changes::Role do
  let(:logger) do
    Logger.new('/dev/null')
  end
  let(:roles_dir) do
    'roles'
  end

  FIXTURES = [
    {
      :name => 'empty filelists',
      :files => [],
      :result => [],
    },
    {
      :name => 'delete role',
      :files => [
        {
          :status => :deleted,
          :path => 'roles/test.rb'
        },
        {
          :status => :modified,
          :path => 'cookbooks/two/cb_one/metadata.rb'
        },
      ],
      :result => [
        ['test', :deleted],
      ],
    },
    {
      :name => 'add/modify a role',
      :files => [
        {
          :status => :modified,
          :path => 'cookbooks/one/cb_one/recipes/test.rb'
        },
        {
          :status => :modified,
          :path => 'roles/test.rb'
        },
        {
          :status => :modified,
          :path => 'cookbooks/one/cb_one/recipes/test3.rb'
        },
      ],
      :result => [
        ['test', :modified],
      ],
    },
  ]

  FIXTURES.each do |fixture|
    it "should handle #{fixture[:name]}" do
      BetweenMeals::Changes::Role.find(
        fixture[:files],
        roles_dir,
        logger
      ).map do |cb|
        [cb.name, cb.status]
      end.
      should eq(fixture[:result])
    end
  end

end
