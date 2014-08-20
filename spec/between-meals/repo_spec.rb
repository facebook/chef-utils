# vim: syntax=ruby:expandtab:shiftwidth=2:softtabstop=2:tabstop=2
require_relative '../../between-meals/repo'
require_relative '../../between-meals/repo/git'
require_relative '../../between-meals/repo/svn'

describe 'BetweenMeals::Repo' do

  let (:class_interface) { BetweenMeals::Repo.public_methods.sort }
  let (:instance_interface) { BetweenMeals::Repo.instance_methods.sort }

  # Misc Repos should not expose anything more than parent class,
  # which default to 'Not implemented'
  [BetweenMeals::Repo::Git, BetweenMeals::Repo::Svn].each do |klass|
    it "#{klass} should conform to BetweenMeals::Repo class interface" do
      klass.public_methods.sort.should eq(class_interface)
    end
    it "#{klass} should conform to BetweenMeals::Repo instance interface" do
      klass.instance_methods.sort.should eq(instance_interface)
    end
  end
end
